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

        // Use the actual pulse interval as set by the user
        timer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pulseUserActivity()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
        print("[ActivityKeeper] Activity timer started with interval: \(pulseInterval)s")
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
