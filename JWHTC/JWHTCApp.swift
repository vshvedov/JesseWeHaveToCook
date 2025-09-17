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
            Image(systemName: (keeper.keepAwake || keeper.appearActive) ? "bolt.fill" : "bolt.slash")
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
