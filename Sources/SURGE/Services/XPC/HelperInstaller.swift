//
//  HelperInstaller.swift
//  SURGE
//
//  Handles installation and management of the privileged helper tool.
//

import Foundation
import ServiceManagement
import AppKit
import Shared

actor HelperInstaller {

    static let shared = HelperInstaller()

    private init() {}

    // MARK: - Installation

    func install() async throws {
        // Use SMAppService for macOS 13+
        let service = SMAppService.daemon(plistName: "com.surge.helper.plist")

        switch service.status {
        case .enabled:
            // Already installed and enabled
            return

        case .requiresApproval:
            // Show alert to guide user to System Settings
            await showApprovalRequired()
            throw HelperError.requiresApproval

        case .notRegistered, .notFound:
            // Register the service
            do {
                try service.register()
            } catch {
                throw HelperError.installationFailed(error.localizedDescription)
            }

        @unknown default:
            throw HelperError.unknownStatus
        }
    }

    func uninstall() throws {
        let service = SMAppService.daemon(plistName: "com.surge.helper.plist")

        do {
            try service.unregister()
        } catch {
            throw HelperError.uninstallationFailed(error.localizedDescription)
        }
    }

    func checkStatus() async -> SMAppService.Status {
        let service = SMAppService.daemon(plistName: "com.surge.helper.plist")
        return service.status
    }

    // MARK: - User Interaction

    @MainActor
    private func showApprovalRequired() {
        let alert = NSAlert()
        alert.messageText = "Privileged Helper Approval Required"
        alert.informativeText = """
        SURGE requires a privileged helper tool to perform system operations.

        To approve:
        1. Open System Settings
        2. Go to General → Login Items
        3. Enable "SURGE Helper" under "Allow in the Background"
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Open System Settings to Login Items
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Errors

enum HelperError: Error, LocalizedError {
    case requiresApproval
    case installationFailed(String)
    case uninstallationFailed(String)
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return "Helper installation requires user approval in System Settings"
        case .installationFailed(let message):
            return "Helper installation failed: \(message)"
        case .uninstallationFailed(let message):
            return "Helper uninstallation failed: \(message)"
        case .unknownStatus:
            return "Unknown helper status"
        }
    }
}
