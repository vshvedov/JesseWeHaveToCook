//
//  SettingsView.swift
//  JWHTC
//
//  Created by Vladyslav Shvedov on 2025-09-17.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var keeper = ActivityKeeper.shared
    @StateObject private var launchAtLogin = LaunchAtLogin.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(spacing: 20) {
                // App Info Section (moved to top)
                VStack(spacing: 8) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.primary)
                        .padding(.bottom, 4)

                    Text("Jesse, We Have To Cook!")
                        .font(.headline)

                    Text("Version 1.3")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("Made with 🍵 by Vladyslav Shvedov")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    HStack(spacing: 12) {
                        Button("mail@vlad.codes") {
                            if let url = URL(string: "mailto:mail@vlad.codes") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .font(.caption)

                        Button("vlad.codes") {
                            if let url = URL(string: "https://vlad.codes") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .font(.caption)
                    }
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    // Launch at Login
                    VStack(alignment: .leading, spacing: 8) {
                        Text("General")
                            .font(.headline)

                        HStack {
                            Toggle("Launch at login", isOn: Binding(
                                get: { launchAtLogin.isEnabled },
                                set: { _ in launchAtLogin.toggle() }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }

                    // Activity Pulse Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity Pulse Interval")
                            .font(.headline)

                        Text("How often to send activity signals when 'Keep Active' is enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("5s")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Slider(
                                value: Binding(
                                    get: { keeper.pulseInterval },
                                    set: { keeper.setPulseInterval($0) }
                                ),
                                in: 5...180,
                                step: 5
                            )

                            Text("3m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Current interval:")
                            Spacer()
                            Text(formatInterval(keeper.pulseInterval))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                Spacer()
            }

            // Bottom bar with extra spacing
            VStack(spacing: 0) {
                HStack {
                    Button("Reset to Default") {
                        keeper.setPulseInterval(30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Extra spacing below Done button
                Spacer()
                    .frame(height: 16)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 420, height: 420)
        .fixedSize()
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        } else {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            if remainingSeconds == 0 {
                return "\(minutes) minute\(minutes == 1 ? "" : "s")"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        }
    }
}

#Preview {
    SettingsView()
}
