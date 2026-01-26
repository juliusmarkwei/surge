//
//  SettingsView.swift
//  SURGE
//
//  Settings/Preferences window.
//

import SwiftUI
import Shared

struct SettingsView: View {

    @EnvironmentObject var appState: AppState

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("updateInterval") private var updateInterval = 3.0
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            helperSettings
                .tabItem {
                    Label("Helper", systemImage: "wrench.and.screwdriver")
                }

            aboutSettings
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)

                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)

                VStack(alignment: .leading) {
                    Text("Update interval: \(Int(updateInterval))s")
                    Slider(value: $updateInterval, in: 1...10, step: 1)
                }
            } header: {
                Text("Preferences")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Helper

    private var helperSettings: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    if appState.isHelperConnected {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not Connected", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                LabeledContent("Version") {
                    Text(XPCConstants.version)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Privileged Helper")
            }

            Section {
                Button("Reinstall Helper") {
                    Task {
                        await appState.installHelper()
                    }
                }

                Button("Remove Helper", role: .destructive) {
                    Task {
                        try? await HelperInstaller.shared.uninstall()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About

    private var aboutSettings: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("SURGE")
                .font(.title)

            Text("Version \(XPCConstants.version)")
                .foregroundColor(.secondary)

            Text("A free, open-source system cleaner for macOS")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/yourusername/surge")!)
                Link("Report Issue", destination: URL(string: "https://github.com/yourusername/surge/issues")!)
            }
            .font(.callout)

            Spacer()

            Text("Licensed under GPLv3")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
    }
}
