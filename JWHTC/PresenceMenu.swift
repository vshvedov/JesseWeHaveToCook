import SwiftUI

struct PresenceMenu: View {
    @ObservedObject var keeper = ActivityKeeper.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Keep Mac awake (no idle sleep)", isOn: Binding(
                get: { keeper.keepAwake },
                set: { keeper.setKeepAwake($0) }
            ))

            Toggle("Appear active (power mgmt pulse)", isOn: Binding(
                get: { keeper.appearActive },
                set: { keeper.setAppearActive($0) }
            ))

            HStack {
                Text("Pulse interval")
                Spacer()
                Text("\(Int(keeper.pulseInterval))s")
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { keeper.pulseInterval },
                set: { keeper.setPulseInterval($0) }
            ), in: 5...180, step: 5)

            Divider()

            Button("Quit PresencePilot") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}