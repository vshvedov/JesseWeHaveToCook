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
            Toggle("Keep Awake", isOn: Binding(
                get: { keeper.keepAwake },
                set: { keeper.setKeepAwake($0) }
            ))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Toggle("Keep Active", isOn: Binding(
                get: { keeper.appearActive },
                set: { keeper.setAppearActive($0) }
            ))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

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
