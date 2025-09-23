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
            Image(systemName: keeper.stayActive ? "flask.fill" : "flask")
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
