//
//  StartupItemsManager.swift
//  PrivilegedHelper
//
//  Manages startup items (Launch Agents/Daemons, Login Items).
//

import Foundation
import Shared
import Logging

fileprivate let startupLogger = Logger(label: "com.surge.helper.startup")

class StartupItemsManager {

    static let shared = StartupItemsManager()

    private let fileManager = FileManager.default

    private let launchAgentsPaths = [
        "/Library/LaunchAgents",
        NSHomeDirectory() + "/Library/LaunchAgents"
    ]

    private let launchDaemonsPaths = [
        "/Library/LaunchDaemons"
    ]

    // System items that should never be disabled
    private let protectedIdentifiers = [
        "com.apple.",
        "com.surge."
    ]

    private init() {}

    // MARK: - Discovery

    func getStartupItems() throws -> [StartupItem] {
        var items: [StartupItem] = []

        // Scan Launch Agents
        for path in launchAgentsPaths {
            let agentItems = try scanLaunchItems(at: path, type: .launchAgent)
            items.append(contentsOf: agentItems)
        }

        // Scan Launch Daemons (requires root)
        for path in launchDaemonsPaths {
            let daemonItems = try scanLaunchItems(at: path, type: .launchDaemon)
            items.append(contentsOf: daemonItems)
        }

        startupLogger.info("Found startup items", metadata: ["count": .stringConvertible(items.count)])

        return items
    }

    private func scanLaunchItems(at path: String, type: StartupItemType) throws -> [StartupItem] {
        var items: [StartupItem] = []

        guard fileManager.fileExists(atPath: path) else {
            return items
        }

        let contents = try fileManager.contentsOfDirectory(atPath: path)

        for filename in contents where filename.hasSuffix(".plist") {
            let itemPath = (path as NSString).appendingPathComponent(filename)

            guard let plistDict = NSDictionary(contentsOfFile: itemPath) as? [String: Any] else {
                continue
            }

            let label = plistDict["Label"] as? String ?? filename.replacingOccurrences(of: ".plist", with: "")
            let disabled = plistDict["Disabled"] as? Bool ?? false
            let isSystemItem = isSystemProtected(label)

            let item = StartupItem(
                name: label,
                path: itemPath,
                type: type,
                enabled: !disabled,
                isSystemItem: isSystemItem
            )

            items.append(item)
        }

        return items
    }

    private func isSystemProtected(_ identifier: String) -> Bool {
        for protected in protectedIdentifiers {
            if identifier.hasPrefix(protected) {
                return true
            }
        }
        return false
    }

    // MARK: - Management

    func setEnabled(item: StartupItem, enabled: Bool) throws {
        guard !item.isSystemItem else {
            throw NSError(domain: "StartupItemsManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot modify system startup items"
            ])
        }

        startupLogger.info("Modifying startup item", metadata: [
            "item": .string(item.name),
            "enabled": .stringConvertible(enabled)
        ])

        guard var plistDict = NSDictionary(contentsOfFile: item.path) as? [String: Any] else {
            throw NSError(domain: "StartupItemsManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read plist: \(item.path)"
            ])
        }

        // Set Disabled key
        plistDict["Disabled"] = !enabled

        // Write back
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )

        try plistData.write(to: URL(fileURLWithPath: item.path))

        // Unload/load with launchctl
        if enabled {
            try launchctlLoad(item.path)
        } else {
            try launchctlUnload(item.path)
        }

        startupLogger.info("Startup item modified successfully")
    }

    private func launchctlLoad(_ path: String) throws {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["load", path]

        task.launch()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw NSError(domain: "StartupItemsManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "launchctl load failed with status \(task.terminationStatus)"
            ])
        }
    }

    private func launchctlUnload(_ path: String) throws {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["unload", path]

        task.launch()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw NSError(domain: "StartupItemsManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "launchctl unload failed with status \(task.terminationStatus)"
            ])
        }
    }
}
