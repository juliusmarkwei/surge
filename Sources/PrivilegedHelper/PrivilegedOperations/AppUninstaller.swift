//
//  AppUninstaller.swift
//  PrivilegedHelper
//
//  Scans for installed applications and safely uninstalls them with associated files
//

import Foundation
import Shared
import Logging

fileprivate let appLogger = Logger(label: "com.surge.helper.appuninstaller")

class AppUninstaller {

    static let shared = AppUninstaller()

    private init() {}

    // MARK: - Application Scanning

    /// List all installed applications
    func listInstalledApps() throws -> [InstalledApp] {
        appLogger.info("Scanning for installed applications")

        var apps: [InstalledApp] = []
        let fileManager = FileManager.default

        // Scan standard application directories
        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for directory in appDirectories {
            guard fileManager.fileExists(atPath: directory) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(atPath: directory)

                for item in contents where item.hasSuffix(".app") {
                    let appPath = directory + "/" + item

                    if let app = try? scanApplication(at: appPath) {
                        apps.append(app)
                    }
                }
            } catch {
                appLogger.warning("Failed to scan directory", metadata: [
                    "path": .string(directory),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        // Sort by total size descending
        apps.sort { $0.totalSize > $1.totalSize }

        appLogger.info("Application scan complete", metadata: [
            "appsFound": .stringConvertible(apps.count)
        ])

        return apps
    }

    /// Scan a single application and find associated files
    private func scanApplication(at path: String) throws -> InstalledApp {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        // Get bundle info
        guard let bundle = Bundle(url: url) else {
            throw XPCError.invalidInput("Not a valid application bundle")
        }

        let bundleIdentifier = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let name = url.deletingPathExtension().lastPathComponent
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String

        // Calculate app bundle size
        let appSize = calculateSize(at: path)

        // Find associated files
        let associatedFiles = findAssociatedFiles(for: bundleIdentifier)

        // Calculate total size
        let associatedSize = associatedFiles.reduce(UInt64(0)) { total, filePath in
            total + calculateSize(at: filePath)
        }
        let totalSize = appSize + associatedSize

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: path,
            version: version,
            size: appSize,
            associatedFiles: associatedFiles,
            totalSize: totalSize
        )
    }

    /// Find associated files for an application
    private func findAssociatedFiles(for bundleIdentifier: String) -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        let homeDir = NSHomeDirectory()

        // Directories to search for associated files
        let searchPaths = [
            homeDir + "/Library/Application Support/" + bundleIdentifier,
            homeDir + "/Library/Caches/" + bundleIdentifier,
            homeDir + "/Library/Preferences/" + bundleIdentifier + ".plist",
            homeDir + "/Library/Saved Application State/" + bundleIdentifier + ".savedState",
            homeDir + "/Library/Logs/" + bundleIdentifier,
            homeDir + "/Library/Containers/" + bundleIdentifier,
            homeDir + "/Library/Group Containers/" + bundleIdentifier,
            "/Library/Application Support/" + bundleIdentifier,
            "/Library/Caches/" + bundleIdentifier,
            "/Library/Preferences/" + bundleIdentifier + ".plist"
        ]

        for path in searchPaths {
            if fileManager.fileExists(atPath: path) {
                files.append(path)
            }
        }

        return files
    }

    // MARK: - Uninstallation

    /// Uninstall an application and its associated files
    func uninstallApp(_ app: InstalledApp) throws {
        appLogger.info("Uninstalling application", metadata: [
            "name": .string(app.name),
            "bundleId": .string(app.bundleIdentifier)
        ])

        let fileManager = FileManager.default

        // Safety checks
        guard !isSystemApp(app) else {
            throw XPCError.permissionDenied("Cannot uninstall system applications")
        }

        // Delete associated files first
        var deletedFiles: [String] = []
        var errors: [String] = []

        for filePath in app.associatedFiles {
            do {
                try fileManager.removeItem(atPath: filePath)
                deletedFiles.append(filePath)
                appLogger.debug("Deleted associated file", metadata: ["path": .string(filePath)])
            } catch {
                let errorMsg = "Failed to delete \(filePath): \(error.localizedDescription)"
                errors.append(errorMsg)
                appLogger.warning("Failed to delete associated file", metadata: [
                    "path": .string(filePath),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        // Delete the application bundle
        do {
            try fileManager.removeItem(atPath: app.path)
            deletedFiles.append(app.path)
            appLogger.info("Application uninstalled successfully", metadata: [
                "name": .string(app.name),
                "deletedFiles": .stringConvertible(deletedFiles.count)
            ])
        } catch {
            let errorMsg = "Failed to delete application bundle: \(error.localizedDescription)"
            errors.append(errorMsg)
            appLogger.error("Failed to delete application bundle", metadata: [
                "path": .string(app.path),
                "error": .string(error.localizedDescription)
            ])
            throw XPCError.operationFailed(errorMsg)
        }

        if !errors.isEmpty {
            appLogger.warning("Uninstallation completed with errors", metadata: [
                "errors": .stringConvertible(errors.count)
            ])
        }
    }

    // MARK: - Helper Methods

    /// Check if an application is a system app (should not be deleted)
    private func isSystemApp(_ app: InstalledApp) -> Bool {
        // System apps are in /Applications and signed by Apple
        let systemApps = [
            "Safari", "Mail", "Calendar", "Contacts", "Maps",
            "Photos", "Messages", "FaceTime", "Music", "TV",
            "Podcasts", "Books", "App Store", "System Settings",
            "Finder", "TextEdit", "Preview", "Calculator",
            "Chess", "Dictionary", "Notes", "Reminders",
            "Stocks", "Voice Memos", "Weather"
        ]

        return systemApps.contains(app.name) ||
               app.path.hasPrefix("/System/") ||
               app.bundleIdentifier.hasPrefix("com.apple.")
    }

    /// Calculate size of a file or directory
    private func calculateSize(at path: String) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            // If not a directory, get file size directly
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                return UInt64(attributes[.size] as? Int64 ?? 0)
            } catch {
                return 0
            }
        }

        // Sum up all file sizes in directory
        for case let file as String in enumerator {
            let fullPath = path + "/" + file
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += UInt64(fileSize)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }
}
