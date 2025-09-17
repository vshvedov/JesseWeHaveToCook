//
//  LaunchAtLogin.swift
//  JWHTC
//
//  Created by Assistant on 2025-09-17.
//

import Foundation
import ServiceManagement
import Combine

@MainActor
class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled != oldValue {
                updateLaunchAtLogin()
            }
        }
    }

    private init() {
        // Check current status
        checkStatus()
    }

    func checkStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLogin() {
        do {
            if isEnabled {
                if SMAppService.mainApp.status == .enabled {
                    print("[LaunchAtLogin] Already enabled")
                    return
                }

                try SMAppService.mainApp.register()
                print("[LaunchAtLogin] Successfully registered for launch at login")
            } else {
                if SMAppService.mainApp.status != .enabled {
                    print("[LaunchAtLogin] Already disabled")
                    return
                }

                try SMAppService.mainApp.unregister()
                print("[LaunchAtLogin] Successfully unregistered from launch at login")
            }

            // Verify the change
            checkStatus()
        } catch {
            print("[LaunchAtLogin] Failed to update launch at login: \(error)")
            // Revert the toggle if operation failed
            checkStatus()
        }
    }

    func toggle() {
        isEnabled.toggle()
    }
}