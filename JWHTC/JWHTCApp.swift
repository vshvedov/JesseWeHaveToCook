//
//  JWHTCApp.swift
//  JWHTC
//
//  Created by Vladyslav Shvedov on 2025-09-17.
//

import SwiftUI

@main
struct JWHTCApp: App {
    @StateObject private var keeper = ActivityKeeper.shared

    var body: some Scene {
        MenuBarExtra {
            PresenceMenu()
        } label: {
            HStack(spacing: 4) {
                if !keeper.stayActive {
                    // Inactive state - crossed flask
                    ZStack {
                        Image(systemName: "flask")
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                } else if keeper.isCurrentlyPulsing {
                    // Actively pulsing - filled flask with timer
                    Image(systemName: "flask.fill")
                    Text(keeper.inactivityDurationString)
                        .font(.system(size: 11, design: .monospaced))
                } else {
                    // Active but waiting for inactivity - empty flask
                    Image(systemName: "flask")
                }
            }
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .onAppear {
                    // Ensure the settings window appears on top
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
                        window.level = .floating
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
