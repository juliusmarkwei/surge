//
//  XPCServer.swift
//  PrivilegedHelper
//
//  XPC server implementation for the privileged helper.
//

import Foundation
import Shared
import Logging

fileprivate let xpcLogger = Logger(label: "com.surge.helper.xpc")

/// XPC listener delegate
class HelperXPCDelegate: NSObject, NSXPCListenerDelegate {

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        xpcLogger.info("Received new XPC connection", metadata: [
            "pid": .stringConvertible(newConnection.processIdentifier)
        ])

        // Validate the client before accepting
        guard ClientValidator.shared.validateClient(newConnection) else {
            xpcLogger.error("Client validation failed", metadata: [
                "pid": .stringConvertible(newConnection.processIdentifier)
            ])
            return false
        }

        xpcLogger.info("Client validated successfully")

        // Configure the connection
        // Note: Using runtime protocol lookup for pure Swift protocol
        if let proto = NSProtocolFromString("PrivilegedHelperProtocol") {
            newConnection.exportedInterface = NSXPCInterface(with: proto)
        }
        newConnection.exportedObject = HelperXPCService()

        newConnection.invalidationHandler = {
            xpcLogger.info("Connection invalidated")
        }

        newConnection.interruptionHandler = {
            xpcLogger.warning("Connection interrupted")
        }

        newConnection.resume()

        return true
    }
}

/// Implementation of the privileged helper protocol
class HelperXPCService: NSObject, PrivilegedHelperProtocol {

    // MARK: - System Information

    func getSystemStats(reply: @escaping (Result<SystemStats, XPCError>) -> Void) {
        xpcLogger.debug("getSystemStats called")

        do {
            let stats = try SystemMonitor.shared.getSystemStats()
            reply(.success(stats))
        } catch {
            xpcLogger.error("Failed to get system stats", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Cleanup Operations

    func scanCleanableFiles(
        categories: [CleanupCategory],
        reply: @escaping (Result<[CleanableItem], XPCError>) -> Void
    ) {
        xpcLogger.info("scanCleanableFiles called", metadata: [
            "categories": .stringConvertible(categories.count)
        ])

        // Validate input
        guard !categories.isEmpty else {
            reply(.failure(.invalidInput("No categories specified")))
            return
        }

        do {
            let items = try SystemCleaner.shared.scanCleanableFiles(categories: categories)
            xpcLogger.info("Scan complete", metadata: [
                "itemsFound": .stringConvertible(items.count),
                "totalSize": .stringConvertible(items.reduce(0) { $0 + $1.size })
            ])
            reply(.success(items))
        } catch {
            xpcLogger.error("Scan failed", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    func deleteFiles(
        paths: [String],
        useQuarantine: Bool,
        reply: @escaping (Result<CleanupResult, XPCError>) -> Void
    ) {
        xpcLogger.info("deleteFiles called", metadata: [
            "count": .stringConvertible(paths.count),
            "useQuarantine": .stringConvertible(useQuarantine)
        ])

        // Validate and sanitize paths
        let sanitizedPaths = paths.compactMap { InputSanitizer.sanitizePath($0) }

        guard sanitizedPaths.count == paths.count else {
            reply(.failure(.invalidInput("Some paths failed validation")))
            return
        }

        do {
            let result = try SystemCleaner.shared.deleteFiles(
                paths: sanitizedPaths,
                useQuarantine: useQuarantine
            )
            xpcLogger.info("Deletion complete", metadata: [
                "deleted": .stringConvertible(result.deletedCount),
                "freed": .stringConvertible(result.freedSpace)
            ])
            reply(.success(result))
        } catch {
            xpcLogger.error("Deletion failed", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Disk Analysis

    func scanDiskUsage(
        path: String,
        maxDepth: Int,
        reply: @escaping (Result<[FileEntry], XPCError>) -> Void
    ) {
        xpcLogger.info("scanDiskUsage called", metadata: [
            "path": .string(path),
            "maxDepth": .stringConvertible(maxDepth)
        ])

        // Validate and sanitize path
        guard let sanitizedPath = InputSanitizer.sanitizePath(path) else {
            reply(.failure(.invalidInput("Invalid path")))
            return
        }

        guard maxDepth > 0 && maxDepth <= 10 else {
            reply(.failure(.invalidInput("maxDepth must be between 1 and 10")))
            return
        }

        do {
            let entries = try DiskScanner.shared.scanDirectory(
                at: sanitizedPath,
                maxDepth: maxDepth
            )
            xpcLogger.info("Scan complete", metadata: [
                "entries": .stringConvertible(entries.count)
            ])
            reply(.success(entries))
        } catch {
            xpcLogger.error("Disk scan failed", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Performance

    func getMemoryInfo(reply: @escaping (Result<MemoryInfo, XPCError>) -> Void) {
        xpcLogger.debug("getMemoryInfo called")

        do {
            let info = try SystemMonitor.shared.getMemoryInfo()
            reply(.success(info))
        } catch {
            xpcLogger.error("Failed to get memory info", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    func getCPUInfo(reply: @escaping (Result<CPUInfo, XPCError>) -> Void) {
        xpcLogger.debug("getCPUInfo called")

        do {
            let info = try SystemMonitor.shared.getCPUInfo()
            reply(.success(info))
        } catch {
            xpcLogger.error("Failed to get CPU info", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    func optimizeMemory(reply: @escaping (Result<MemoryOptimizationResult, XPCError>) -> Void) {
        xpcLogger.info("optimizeMemory called")

        do {
            let result = try MemoryOptimizer.shared.optimizeMemory()
            xpcLogger.info("Memory optimization complete", metadata: [
                "freed": .stringConvertible(result.freedMemory)
            ])
            reply(.success(result))
        } catch {
            xpcLogger.error("Memory optimization failed", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Startup Items

    func getStartupItems(reply: @escaping (Result<[StartupItem], XPCError>) -> Void) {
        xpcLogger.info("getStartupItems called")

        do {
            let items = try StartupItemsManager.shared.getStartupItems()
            xpcLogger.info("Found startup items", metadata: ["count": .stringConvertible(items.count)])
            reply(.success(items))
        } catch {
            xpcLogger.error("Failed to get startup items", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    func setStartupItemEnabled(
        item: StartupItem,
        enabled: Bool,
        reply: @escaping (Result<Void, XPCError>) -> Void
    ) {
        xpcLogger.info("setStartupItemEnabled called", metadata: [
            "item": .string(item.name),
            "enabled": .stringConvertible(enabled)
        ])

        // Prevent disabling system-critical items
        guard !item.isSystemItem else {
            reply(.failure(.permissionDenied("Cannot modify system startup items")))
            return
        }

        do {
            try StartupItemsManager.shared.setEnabled(item: item, enabled: enabled)
            reply(.success(()))
        } catch {
            xpcLogger.error("Failed to modify startup item", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Security

    func scanForMalware(reply: @escaping (Result<[SecurityThreat], XPCError>) -> Void) {
        xpcLogger.info("scanForMalware called")

        do {
            let threats = try SecurityScanner.shared.scanForThreats()
            xpcLogger.info("Malware scan complete", metadata: ["threats": .stringConvertible(threats.count)])
            reply(.success(threats))
        } catch {
            xpcLogger.error("Malware scan failed", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    func removeThreat(
        threat: SecurityThreat,
        reply: @escaping (Result<Void, XPCError>) -> Void
    ) {
        xpcLogger.info("removeThreat called", metadata: ["threat": .string(threat.name)])

        do {
            try SecurityScanner.shared.removeThreat(threat)
            reply(.success(()))
        } catch {
            xpcLogger.error("Failed to remove threat", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Maintenance

    func runMaintenance(
        tasks: [MaintenanceTask],
        reply: @escaping (Result<MaintenanceResult, XPCError>) -> Void
    ) {
        xpcLogger.info("runMaintenance called", metadata: ["tasks": .stringConvertible(tasks.count)])

        do {
            let result = try MaintenanceRunner.shared.runTasks(tasks)
            xpcLogger.info("Maintenance complete", metadata: [
                "completed": .stringConvertible(result.completedTasks.count),
                "failed": .stringConvertible(result.failedTasks.count)
            ])
            reply(.success(result))
        } catch {
            xpcLogger.error("Maintenance failed", metadata: ["error": .string(error.localizedDescription)])
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }

    // MARK: - Helper Management

    func getVersion(reply: @escaping (String) -> Void) {
        reply(XPCConstants.version)
    }

    func ping(reply: @escaping () -> Void) {
        xpcLogger.debug("ping received")
        reply()
    }
}
