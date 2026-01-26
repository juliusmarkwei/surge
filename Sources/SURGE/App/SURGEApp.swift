//
//  SURGEApp.swift
//  SURGE
//
//  Main application entry point with menu bar integration.
//

import SwiftUI
import AppKit

@main
struct SURGEApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)

        // Main window (hidden by default, shown on demand)
        WindowGroup(id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .defaultPosition(.center)

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Initialize privileged helper connection
        Task {
            await AppState.shared.initializeHelperConnection()
        }

        // Start system monitoring
        AppState.shared.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running when windows are closed (menu bar app)
        return false
    }
}
