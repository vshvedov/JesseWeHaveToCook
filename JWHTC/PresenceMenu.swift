//
//  PresenceMenu.swift
//  JWHTC
//
//  Created by Vladyslav Shvedov on 2025-09-17.
//


import SwiftUI

struct PresenceMenu: View {
    @ObservedObject var keeper = ActivityKeeper.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle("Stay Active", isOn: Binding(
                get: { keeper.stayActive },
                set: { keeper.setStayActive($0) }
            ))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .help("Prevents sleep, screensaver and keeps you active.")

            Divider()
                .padding(.vertical, 4)

            Button(action: {
                openWindow(id: "settings")
            }) {
                Label("Settings...", systemImage: "gearshape")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Stop cooking, Jesse!", systemImage: "power")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(width: 250)
    }
}
