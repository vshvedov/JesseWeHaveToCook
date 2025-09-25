//
//  ActivityKeeper.swift
//  PresencePilot
//
//  Created by Vladyslav Shvedov on 2025-09-17.
//

import Foundation
import Combine
import IOKit.pwr_mgt
import CoreGraphics
import AppKit
import Quartz

@MainActor
final class ActivityKeeper: ObservableObject {
    static let shared = ActivityKeeper()

    // UI state - single combined option
    @Published var stayActive = false
    @Published var pulseInterval: TimeInterval = 20
    @Published var inactivityThreshold: TimeInterval = 300 // 5 minutes default
    @Published var isCurrentlyPulsing = false // tracks if we're actively pulsing due to inactivity

    // Internals
    private var idleSleepAssertion: IOPMAssertionID = 0
    private var displaySleepAssertion: IOPMAssertionID = 0
    private var userIdleAssertion: IOPMAssertionID = 0
    private var processActivity: NSObjectProtocol?
    private var pulseTimer: Timer?
    private var inactivityCheckTimer: Timer?
    private var lastActivityTime: Date = Date()

    private init() {
        // Start with stay active disabled by default
        Task { @MainActor in
            setStayActive(false)
        }
    }

    // MARK: - Stay Active (prevents sleep, screensaver, and app inactivity)
    func setStayActive(_ enabled: Bool) {
        stayActive = enabled
        if enabled {
            beginStayActive()
        } else {
            endStayActive()
        }
    }

    private func beginStayActive() {
        print("[ActivityKeeper] Starting stay-active mode")

        // Start monitoring for inactivity
        startInactivityMonitoring()
        // Always prevent sleep when active mode is on
        beginNoSleep()
    }

    private func endStayActive() {
        print("[ActivityKeeper] Ending stay-active mode")

        // Stop all protection mechanisms
        endNoSleep()
        stopInactivityMonitoring()
        stopPulseTimer()
        isCurrentlyPulsing = false
    }

    private func beginNoSleep() {
        print("[ActivityKeeper] Starting sleep prevention")

        if processActivity == nil {
            // Prevents both system idle sleep and display sleep
            processActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .automaticTerminationDisabled, .suddenTerminationDisabled, .userInitiated],
                reason: "JWHTC: Keep system active"
            )
            print("[ActivityKeeper] ProcessInfo activity started")
        }

        if idleSleepAssertion == 0 {
            let reason = "JWHTC: Prevent idle system sleep" as CFString
            let res = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &idleSleepAssertion
            )
            if res == kIOReturnSuccess {
                print("[ActivityKeeper] NoIdleSleep assertion created: \(idleSleepAssertion)")
            } else {
                print("[ActivityKeeper] NoIdleSleep assertion failed: \(res)")
            }
        }

        if displaySleepAssertion == 0 {
            let reason = "JWHTC: Prevent display sleep" as CFString
            let res = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displaySleepAssertion
            )
            if res == kIOReturnSuccess {
                print("[ActivityKeeper] NoDisplaySleep assertion created: \(displaySleepAssertion)")
            } else {
                print("[ActivityKeeper] NoDisplaySleep assertion failed: \(res)")
            }
        }

        // Additional assertion specifically for preventing screensaver and user idle
        if userIdleAssertion == 0 {
            let reason = "JWHTC: Prevent user idle (screensaver)" as CFString
            let res = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &userIdleAssertion
            )
            if res == kIOReturnSuccess {
                print("[ActivityKeeper] PreventUserIdleSystemSleep assertion created: \(userIdleAssertion)")
            } else {
                print("[ActivityKeeper] PreventUserIdleSystemSleep assertion failed: \(res)")
            }
        }
    }

    private func endNoSleep() {
        print("[ActivityKeeper] Ending sleep prevention")

        if let act = processActivity {
            ProcessInfo.processInfo.endActivity(act)
            processActivity = nil
            print("[ActivityKeeper] ProcessInfo activity ended")
        }
        if idleSleepAssertion != 0 {
            let res = IOPMAssertionRelease(idleSleepAssertion)
            print("[ActivityKeeper] NoIdleSleep assertion released: \(res == kIOReturnSuccess ? "success" : "failed")")
            idleSleepAssertion = 0
        }
        if displaySleepAssertion != 0 {
            let res = IOPMAssertionRelease(displaySleepAssertion)
            print("[ActivityKeeper] NoDisplaySleep assertion released: \(res == kIOReturnSuccess ? "success" : "failed")")
            displaySleepAssertion = 0
        }
        if userIdleAssertion != 0 {
            let res = IOPMAssertionRelease(userIdleAssertion)
            print("[ActivityKeeper] PreventUserIdleSystemSleep assertion released: \(res == kIOReturnSuccess ? "success" : "failed")")
            userIdleAssertion = 0
        }
    }

    // MARK: - Configuration controls
    func setPulseInterval(_ seconds: TimeInterval) {
        pulseInterval = max(5, seconds) // safety floor
        if pulseTimer != nil && isCurrentlyPulsing {
            startPulseTimer()
        }
    }

    func setInactivityThreshold(_ minutes: TimeInterval) {
        inactivityThreshold = minutes * 60 // convert to seconds
        if stayActive {
            // Restart monitoring with new threshold
            stopInactivityMonitoring()
            startInactivityMonitoring()
        }
    }

    // MARK: - Inactivity Monitoring
    private func startInactivityMonitoring() {
        stopInactivityMonitoring()
        lastActivityTime = Date()

        // Check for inactivity every second
        inactivityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkInactivity()
            }
        }
        if let t = inactivityCheckTimer {
            RunLoop.main.add(t, forMode: .common)
        }
        print("[ActivityKeeper] Inactivity monitoring started with threshold: \(inactivityThreshold)s")
    }

    private func stopInactivityMonitoring() {
        if Thread.isMainThread {
            inactivityCheckTimer?.invalidate()
            inactivityCheckTimer = nil
        } else {
            DispatchQueue.main.sync {
                self.inactivityCheckTimer?.invalidate()
                self.inactivityCheckTimer = nil
            }
        }
    }

    private func checkInactivity() {
        // Check for actual user input events (keyboard and mouse)
        let keyboardIdleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let mouseClickIdleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let mouseMovedIdleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let rightClickIdleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .rightMouseDown)
        let scrollIdleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .scrollWheel)

        // Get the minimum idle time from all user input sources
        let minIdleTime = min(keyboardIdleTime, mouseClickIdleTime, mouseMovedIdleTime, rightClickIdleTime, scrollIdleTime)

        if minIdleTime < 1.0 {
            // User is active
            lastActivityTime = Date()
            if isCurrentlyPulsing {
                print("[ActivityKeeper] User activity detected (idle: \(minIdleTime)s), stopping pulses")
                stopPulseTimer()
                isCurrentlyPulsing = false
            }
        } else {
            // Check if we've been idle long enough
            let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
            if timeSinceLastActivity >= inactivityThreshold && !isCurrentlyPulsing && stayActive {
                print("[ActivityKeeper] Inactivity threshold reached (\(inactivityThreshold)s), starting pulses")
                isCurrentlyPulsing = true
                startPulseTimer()
            }
        }
    }

    private func startPulseTimer() {
        stopPulseTimer()
        pulseUserActivity() // fire immediately

        // Use the actual pulse interval as set by the user
        pulseTimer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pulseUserActivity()
            }
        }
        if let t = pulseTimer {
            RunLoop.main.add(t, forMode: .common)
        }
        print("[ActivityKeeper] Pulse timer started with interval: \(pulseInterval)s")
    }

    private func stopPulseTimer() {
        if Thread.isMainThread {
            pulseTimer?.invalidate()
            pulseTimer = nil
        } else {
            DispatchQueue.main.sync {
                self.pulseTimer?.invalidate()
                self.pulseTimer = nil
            }
        }
    }

    private func pulseUserActivity() {
        print("[ActivityKeeper] Sending non-intrusive activity pulse...")

        // 1. IOPMAssertionDeclareUserActivity - tells the system user is active
        // This is the primary method that resets idle timers without any input events
        var activityID = IOPMAssertionID(0)
        let userActivityOptions = IOPMUserActiveType(kIOPMUserActiveLocal.rawValue | kIOPMUserActiveRemote.rawValue)
        let activityResult = IOPMAssertionDeclareUserActivity(
            "JWHTC: Non-intrusive user active pulse" as CFString,
            userActivityOptions,
            &activityID
        )

        if activityResult == kIOReturnSuccess && activityID != 0 {
            print("[ActivityKeeper] User activity declared (ID: \(activityID))")
            // Hold the assertion longer to ensure apps detect the activity
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let releaseResult = IOPMAssertionRelease(activityID)
                if releaseResult != kIOReturnSuccess {
                    print("[ActivityKeeper] Warning: Failed to release activity ID \(activityID)")
                }
            }
        } else {
            print("[ActivityKeeper] User activity declaration failed: \(activityResult)")
        }

        // 2. Temporarily create and release a PreventUserIdleSystemSleep assertion
        // This signals to the system and apps that user activity is happening
        var tempUserAssertion = IOPMAssertionID(0)
        let tempResult = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "JWHTC: Activity signal" as CFString,
            &tempUserAssertion
        )

        if tempResult == kIOReturnSuccess && tempUserAssertion != 0 {
            print("[ActivityKeeper] Temporary idle prevention assertion created")
            // Hold for 2 seconds then release - this creates a "pulse" of activity
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let releaseResult = IOPMAssertionRelease(tempUserAssertion)
                if releaseResult == kIOReturnSuccess {
                    print("[ActivityKeeper] Temporary assertion released successfully")
                } else {
                    print("[ActivityKeeper] Warning: Failed to release temp assertion \(tempUserAssertion)")
                }
            }
        }

        // 3. Briefly refresh the ProcessInfo activity to signal continued usage
        // This helps apps that monitor process-level activity states
        if let currentActivity = processActivity {
            ProcessInfo.processInfo.endActivity(currentActivity)
            processActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .userInitiated, .latencyCritical],
                reason: "JWHTC: Activity refresh"
            )
            print("[ActivityKeeper] ProcessInfo activity refreshed")
        }
    }

    deinit {
        // Cleanup happens automatically when app terminates
        // Assertions are released by the system
    }
}
