//
//  XPCClient.swift
//  SURGE
//
//  XPC client for communicating with the privileged helper.
//

import Foundation
import Shared

actor XPCClient {

    static let shared = XPCClient()

    private(set) var isConnected: Bool = false

    private var connection: NSXPCConnection?
    private let connectionQueue = DispatchQueue(label: "com.surge.xpc", qos: .userInitiated)

    private init() {}

    // MARK: - Connection Management

    func connect() async throws {
        guard connection == nil else { return }

        let newConnection = NSXPCConnection(machServiceName: XPCConstants.helperMachServiceName, options: .privileged)
        // Note: Using runtime protocol lookup for pure Swift protocol
        if let proto = NSProtocolFromString("PrivilegedHelperProtocol") {
            newConnection.remoteObjectInterface = NSXPCInterface(with: proto)
        }

        newConnection.invalidationHandler = { [weak self] in
            Task {
                await self?.handleInvalidation()
            }
        }

        newConnection.interruptionHandler = { [weak self] in
            Task {
                await self?.handleInterruption()
            }
        }

        newConnection.resume()

        self.connection = newConnection
        self.isConnected = true
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
        isConnected = false
    }

    private func handleInvalidation() {
        connection = nil
        isConnected = false
    }

    private func handleInterruption() {
        // Connection interrupted but not invalidated - might reconnect
        isConnected = false
    }

    private func getProxy() throws -> PrivilegedHelperProtocol {
        guard let connection = connection else {
            throw XPCError.connectionFailed
        }

        return connection.remoteObjectProxyWithErrorHandler { error in
            print("XPC Error: \(error)")
        } as! PrivilegedHelperProtocol
    }

    // MARK: - System Information

    func getSystemStats() async throws -> SystemStats {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getSystemStats { result in
                continuation.resume(with: result)
            }
        }
    }

    func getMemoryInfo() async throws -> MemoryInfo {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getMemoryInfo { result in
                continuation.resume(with: result)
            }
        }
    }

    func getCPUInfo() async throws -> CPUInfo {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getCPUInfo { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Cleanup

    func scanCleanableFiles(categories: [CleanupCategory]) async throws -> [CleanableItem] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.scanCleanableFiles(categories: categories) { result in
                continuation.resume(with: result)
            }
        }
    }

    func deleteFiles(paths: [String], useQuarantine: Bool) async throws -> CleanupResult {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.deleteFiles(paths: paths, useQuarantine: useQuarantine) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Disk Analysis

    func scanDiskUsage(path: String, maxDepth: Int) async throws -> [FileEntry] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.scanDiskUsage(path: path, maxDepth: maxDepth) { result in
                continuation.resume(with: result)
            }
        }
    }

    func scanTreeMap(path: String, maxDepth: Int) async throws -> TreeMapItem {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.scanTreeMap(path: path, maxDepth: maxDepth) { result in
                continuation.resume(with: result)
            }
        }
    }

    func findDuplicates(paths: [String], minSize: UInt64) async throws -> [DuplicateGroup] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.findDuplicates(paths: paths, minSize: minSize) { result in
                continuation.resume(with: result)
            }
        }
    }

    func findLargeOldFiles(paths: [String], minSize: UInt64, minAge: Int) async throws -> [LargeFileItem] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.findLargeOldFiles(paths: paths, minSize: minSize, minAge: minAge) { result in
                continuation.resume(with: result)
            }
        }
    }

    func listInstalledApps() async throws -> [InstalledApp] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.listInstalledApps { result in
                continuation.resume(with: result)
            }
        }
    }

    func uninstallApp(_ app: InstalledApp) async throws {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.uninstallApp(app: app) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Performance

    func optimizeMemory() async throws -> MemoryOptimizationResult {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.optimizeMemory { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Startup Items

    func getStartupItems() async throws -> [StartupItem] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getStartupItems { result in
                continuation.resume(with: result)
            }
        }
    }

    func setStartupItemEnabled(item: StartupItem, enabled: Bool) async throws {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.setStartupItemEnabled(item: item, enabled: enabled) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Security

    func scanForMalware() async throws -> [SecurityThreat] {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.scanForMalware { result in
                continuation.resume(with: result)
            }
        }
    }

    func removeThreat(_ threat: SecurityThreat) async throws {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.removeThreat(threat: threat) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Maintenance

    func runMaintenance(tasks: [MaintenanceTask]) async throws -> MaintenanceResult {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.runMaintenance(tasks: tasks) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Helper Management

    func getVersion() async throws -> String {
        let proxy = try getProxy()

        return await withCheckedContinuation { continuation in
            proxy.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }

    func ping() async throws {
        let proxy = try getProxy()

        return await withCheckedContinuation { continuation in
            proxy.ping {
                continuation.resume()
            }
        }
    }
}
