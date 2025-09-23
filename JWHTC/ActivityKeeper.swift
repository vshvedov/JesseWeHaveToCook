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

@MainActor
final class ActivityKeeper: ObservableObject {
    static let shared = ActivityKeeper()

    // UI state - single combined option
    @Published var stayActive = true
    @Published var pulseInterval: TimeInterval = 20

    // Internals
    private var idleSleepAssertion: IOPMAssertionID = 0
    private var displaySleepAssertion: IOPMAssertionID = 0
    private var userIdleAssertion: IOPMAssertionID = 0
    private var processActivity: NSObjectProtocol?
    private var timer: Timer?

    private init() {
        // Start with stay active enabled by default
        Task { @MainActor in
            setStayActive(true)
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

        // Start all protection mechanisms
        beginNoSleep()
        startUserActivityTimer()
    }

    private func endStayActive() {
        print("[ActivityKeeper] Ending stay-active mode")

        // Stop all protection mechanisms
        endNoSleep()
        stopUserActivityTimer()
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
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &userIdleAssertion
            )
            if res == kIOReturnSuccess {
                print("[ActivityKeeper] PreventUserIdleDisplaySleep assertion created: \(userIdleAssertion)")
            } else {
                print("[ActivityKeeper] PreventUserIdleDisplaySleep assertion failed: \(res)")
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
            print("[ActivityKeeper] PreventUserIdleDisplaySleep assertion released: \(res == kIOReturnSuccess ? "success" : "failed")")
            userIdleAssertion = 0
        }
    }

    // MARK: - Pulse interval control
    func setPulseInterval(_ seconds: TimeInterval) {
        pulseInterval = max(5, seconds) // safety floor
        if timer != nil && stayActive {
            startUserActivityTimer()
        }
    }

    private func startUserActivityTimer() {
        stopUserActivityTimer()
        pulseUserActivity() // fire immediately

        // Create timer with shorter interval for better detection
        let effectiveInterval = min(pulseInterval, 10)
        timer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pulseUserActivity()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
        print("[ActivityKeeper] Activity timer started with interval: \(effectiveInterval)s")
    }

    private func stopUserActivityTimer() {
        if Thread.isMainThread {
            timer?.invalidate()
            timer = nil
        } else {
            DispatchQueue.main.sync {
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }

    private func pulseUserActivity() {
        // Send multiple types of activity signals for maximum compatibility

        // 1. Simulate minimal mouse movement to trigger user activity
        // This is what Slack actually needs - real input events
        if let currentEvent = CGEvent(source: nil) {
            let currentLocation = currentEvent.location

            // Create a tiny mouse movement (1 pixel right, then back)
            // This is imperceptible to the user but registers as activity
            let moveRight = CGEvent(mouseEventSource: nil,
                                   mouseType: .mouseMoved,
                                   mouseCursorPosition: CGPoint(x: currentLocation.x + 1, y: currentLocation.y),
                                   mouseButton: .left)

            let moveBack = CGEvent(mouseEventSource: nil,
                                 mouseType: .mouseMoved,
                                 mouseCursorPosition: currentLocation,
                                 mouseButton: .left)

            // Post the events to simulate actual mouse movement
            moveRight?.post(tap: .cghidEventTap)

            // Small delay to ensure the movement registers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                moveBack?.post(tap: .cghidEventTap)
            }

            print("[ActivityKeeper] Mouse movement pulse sent")
        }

        // 2. Declare user activity
        // Using both local and remote flags
        var activityID = IOPMAssertionID(0)
        let userActivityOptions = IOPMUserActiveType(kIOPMUserActiveLocal.rawValue | kIOPMUserActiveRemote.rawValue)
        let activityResult = IOPMAssertionDeclareUserActivity(
            "JWHTC: User active pulse" as CFString,
            userActivityOptions,
            &activityID
        )

        if activityResult == kIOReturnSuccess, activityID != 0 {
            print("[ActivityKeeper] User activity pulse sent (ID: \(activityID))")
            // Keep assertion for a brief moment to ensure it registers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                _ = IOPMAssertionRelease(activityID)
            }
        } else {
            print("[ActivityKeeper] User activity pulse failed: \(activityResult)")
        }

        // 3. Create a temporary PreventUserIdleSystemSleep assertion
        // This tells the system the user is actively using the machine
        var tempUserAssertion = IOPMAssertionID(0)
        let tempResult = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "JWHTC: Temporary activity" as CFString,
            &tempUserAssertion
        )

        if tempResult == kIOReturnSuccess, tempUserAssertion != 0 {
            // Hold for half a second then release
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                _ = IOPMAssertionRelease(tempUserAssertion)
            }
        }

        // 4. Briefly toggle the process activity to signal we're still active
        // This helps with some apps that monitor process activity
        if processActivity != nil {
            if let act = processActivity {
                ProcessInfo.processInfo.endActivity(act)
                processActivity = ProcessInfo.processInfo.beginActivity(
                    options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .userInitiated, .latencyCritical],
                    reason: "JWHTC: Keep system active"
                )
            }
        }
    }

    deinit {
        // Cleanup happens automatically when app terminates
        // Assertions are released by the system
    }
}
