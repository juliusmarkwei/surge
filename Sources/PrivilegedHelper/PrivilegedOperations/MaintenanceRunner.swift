//
//  MaintenanceRunner.swift
//  PrivilegedHelper
//
//  Runs system maintenance tasks.
//

import Foundation
import Logging
import Shared

fileprivate let maintenanceLogger = Logger(label: "com.surge.helper.maintenance")

class MaintenanceRunner {

    static let shared = MaintenanceRunner()

    private init() {}

    func runTasks(_ tasks: [MaintenanceTask]) throws -> MaintenanceResult {
        maintenanceLogger.info("Starting maintenance tasks", metadata: [
            "count": .stringConvertible(tasks.count)
        ])

        var completedTasks: [MaintenanceTask] = []
        var failedTasks: [MaintenanceTask] = []
        var errors: [String] = []

        for task in tasks {
            do {
                try runTask(task)
                completedTasks.append(task)
                maintenanceLogger.info("Completed task", metadata: ["task": .string(task.rawValue)])
            } catch {
                failedTasks.append(task)
                let errorMsg = "Task \(task.rawValue) failed: \(error.localizedDescription)"
                errors.append(errorMsg)
                maintenanceLogger.error("Task failed", metadata: [
                    "task": .string(task.rawValue),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        return MaintenanceResult(
            completedTasks: completedTasks,
            failedTasks: failedTasks,
            errors: errors
        )
    }

    private func runTask(_ task: MaintenanceTask) throws {
        switch task {
        case .rebuildSpotlight:
            try rebuildSpotlight()
        case .rebuildLaunchServices:
            try rebuildLaunchServices()
        case .clearDNSCache:
            try clearDNSCache()
        case .repairPermissions:
            try repairPermissions()
        case .verifyDisk:
            try verifyDisk()
        }
    }

    // MARK: - Individual Tasks

    private func rebuildSpotlight() throws {
        try runCommand("/usr/bin/mdutil", arguments: ["-E", "/"])
    }

    private func rebuildLaunchServices() throws {
        try runCommand(
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        )
    }

    private func clearDNSCache() throws {
        try runCommand("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        try runCommand("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
    }

    private func repairPermissions() throws {
        try runCommand("/usr/sbin/diskutil", arguments: ["repairPermissions", "/"])
    }

    private func verifyDisk() throws {
        try runCommand("/usr/sbin/diskutil", arguments: ["verifyVolume", "/"])
    }

    // MARK: - Helper

    private func runCommand(_ path: String, arguments: [String]) throws {
        let task = Process()
        task.launchPath = path
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.launch()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "MaintenanceRunner", code: Int(task.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Command failed with status \(task.terminationStatus): \(output)"
            ])
        }
    }
}
