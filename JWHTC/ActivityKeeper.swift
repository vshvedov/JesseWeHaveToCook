//
//  ActivityKeeper.swift
//  PresencePilot
//
//  Created by Vladyslav Shvedov on 2025-09-17.
//

import Foundation
import Combine
import IOKit.pwr_mgt

@MainActor
final class ActivityKeeper: ObservableObject {
    static let shared = ActivityKeeper()

    // UI state
    @Published var keepAwake = true
    @Published var appearActive = true
    @Published var pulseInterval: TimeInterval = 30

    // Internals
    private var idleSleepAssertion: IOPMAssertionID = 0
    private var displaySleepAssertion: IOPMAssertionID = 0
    private var userIdleAssertion: IOPMAssertionID = 0
    private var processActivity: NSObjectProtocol?
    private var timer: Timer?

    private init() {
        // Start with keep awake enabled by default
        Task { @MainActor in
            setKeepAwake(true)
        }
    }

    // MARK: - Keep-awake (no idle sleep + no display sleep/screensaver)
    func setKeepAwake(_ enabled: Bool) {
        keepAwake = enabled
        enabled ? beginNoSleep() : endNoSleep()
    }

    private func beginNoSleep() {
        print("[ActivityKeeper] Starting keep-awake mode")

        if processActivity == nil {
            // Prevents both system idle sleep and display sleep
            processActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .automaticTerminationDisabled, .suddenTerminationDisabled],
                reason: "JWHTC: Keep display awake"
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

        // Additional assertion specifically for preventing screensaver
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
        print("[ActivityKeeper] Ending keep-awake mode")

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

    // MARK: - “Appear active” without keystrokes/mouse movement
    func setAppearActive(_ enabled: Bool) {
        appearActive = enabled
        enabled ? startUserActivityTimer() : stopUserActivityTimer()
    }

    func setPulseInterval(_ seconds: TimeInterval) {
        pulseInterval = max(5, seconds) // safety floor
        if timer != nil { startUserActivityTimer() }
    }

    private func startUserActivityTimer() {
        stopUserActivityTimer()
        pulseUserActivity() // fire immediately
        timer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] _ in
            self?.pulseUserActivity()
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
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
        // Resets idle timer
        var id = IOPMAssertionID(0)
        let r = IOPMAssertionDeclareUserActivity(
            "JWHTC: User active pulse" as CFString,
            kIOPMUserActiveLocal,
            &id
        )
        if r == kIOReturnSuccess, id != 0 {
            print("[ActivityKeeper] Activity pulse sent (ID: \(id))")
            _ = IOPMAssertionRelease(id) // release immediately
        } else {
            print("[ActivityKeeper] Activity pulse failed: \(r)")
        }
    }

    deinit {
        Task { @MainActor in
            endNoSleep()
            stopUserActivityTimer()
        }
    }
}
