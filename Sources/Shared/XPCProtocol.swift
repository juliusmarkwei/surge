//
//  XPCProtocol.swift
//  SURGE - System Utility for Reclaiming Gigabytes Efficiently
//
//  Defines the XPC communication protocol between the main app and privileged helper.
//  This protocol must be implemented securely with client validation.
//

import Foundation

/// Protocol for communication with the privileged helper tool
/// Note: This protocol uses Swift types and Result, so it cannot be @objc
public protocol PrivilegedHelperProtocol {

    // MARK: - System Information

    /// Get current system statistics
    /// - Parameter reply: Callback with system stats or error
    func getSystemStats(reply: @escaping (Result<SystemStats, XPCError>) -> Void)

    // MARK: - Cleanup Operations

    /// Scan for cleanable files in specified categories
    /// - Parameters:
    ///   - categories: Categories to scan (caches, logs, trash, etc.)
    ///   - reply: Callback with scan results or error
    func scanCleanableFiles(
        categories: [CleanupCategory],
        reply: @escaping (Result<[CleanableItem], XPCError>) -> Void
    )

    /// Delete specified files/directories
    /// - Parameters:
    ///   - paths: Array of file paths to delete
    ///   - useQuarantine: Whether to move to quarantine folder instead of immediate deletion
    ///   - reply: Callback with deletion results
    func deleteFiles(
        paths: [String],
        useQuarantine: Bool,
        reply: @escaping (Result<CleanupResult, XPCError>) -> Void
    )

    // MARK: - Disk Analysis

    /// Scan directory tree for disk space analysis
    /// - Parameters:
    ///   - path: Root path to scan
    ///   - maxDepth: Maximum directory depth
    ///   - reply: Streaming callback with file entries
    func scanDiskUsage(
        path: String,
        maxDepth: Int,
        reply: @escaping (Result<[FileEntry], XPCError>) -> Void
    )

    /// Scan directory tree for TreeMap visualization
    /// - Parameters:
    ///   - path: Root path to scan
    ///   - maxDepth: Maximum directory depth (default: 5)
    ///   - reply: Callback with tree structure
    func scanTreeMap(
        path: String,
        maxDepth: Int,
        reply: @escaping (Result<TreeMapItem, XPCError>) -> Void
    )

    /// Find duplicate files using SHA-256 hashing
    /// - Parameters:
    ///   - paths: Paths to scan for duplicates
    ///   - minSize: Minimum file size to consider (default: 1MB)
    ///   - reply: Callback with duplicate groups
    func findDuplicates(
        paths: [String],
        minSize: UInt64,
        reply: @escaping (Result<[DuplicateGroup], XPCError>) -> Void
    )

    /// Find large and old files
    /// - Parameters:
    ///   - paths: Paths to scan
    ///   - minSize: Minimum file size in bytes (default: 100MB)
    ///   - minAge: Minimum age in days (default: 365)
    ///   - reply: Callback with large/old files
    func findLargeOldFiles(
        paths: [String],
        minSize: UInt64,
        minAge: Int,
        reply: @escaping (Result<[LargeFileItem], XPCError>) -> Void
    )

    /// List installed applications
    func listInstalledApps(reply: @escaping (Result<[InstalledApp], XPCError>) -> Void)

    /// Uninstall an application completely
    /// - Parameters:
    ///   - app: Application to uninstall
    ///   - reply: Callback with result
    func uninstallApp(
        app: InstalledApp,
        reply: @escaping (Result<Void, XPCError>) -> Void
    )

    // MARK: - Performance

    /// Get detailed memory information
    func getMemoryInfo(reply: @escaping (Result<MemoryInfo, XPCError>) -> Void)

    /// Get CPU usage per core
    func getCPUInfo(reply: @escaping (Result<CPUInfo, XPCError>) -> Void)

    /// Perform memory optimization
    func optimizeMemory(reply: @escaping (Result<MemoryOptimizationResult, XPCError>) -> Void)

    // MARK: - Startup Items

    /// List all startup items (Launch Agents/Daemons)
    func getStartupItems(reply: @escaping (Result<[StartupItem], XPCError>) -> Void)

    /// Enable/disable a startup item
    func setStartupItemEnabled(
        item: StartupItem,
        enabled: Bool,
        reply: @escaping (Result<Void, XPCError>) -> Void
    )

    // MARK: - Security

    /// Scan for malware signatures
    func scanForMalware(reply: @escaping (Result<[SecurityThreat], XPCError>) -> Void)

    /// Remove detected security threat
    func removeThreat(
        threat: SecurityThreat,
        reply: @escaping (Result<Void, XPCError>) -> Void
    )

    // MARK: - Maintenance

    /// Run system maintenance scripts
    func runMaintenance(
        tasks: [MaintenanceTask],
        reply: @escaping (Result<MaintenanceResult, XPCError>) -> Void
    )

    // MARK: - Helper Management

    /// Get helper version
    func getVersion(reply: @escaping (String) -> Void)

    /// Health check
    func ping(reply: @escaping () -> Void)
}

// MARK: - Data Transfer Objects

/// System statistics
public struct SystemStats: Codable, Sendable {
    public let cpuUsage: Double // 0.0 - 100.0
    public let memoryUsed: UInt64 // bytes
    public let memoryTotal: UInt64 // bytes
    public let diskUsed: UInt64 // bytes
    public let diskTotal: UInt64 // bytes
    public let timestamp: Date

    public init(cpuUsage: Double, memoryUsed: UInt64, memoryTotal: UInt64,
                diskUsed: UInt64, diskTotal: UInt64, timestamp: Date) {
        self.cpuUsage = cpuUsage
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.diskUsed = diskUsed
        self.diskTotal = diskTotal
        self.timestamp = timestamp
    }
}

/// Cleanup category
public enum CleanupCategory: String, Codable, Sendable, CaseIterable {
    case systemCaches
    case userCaches
    case logs
    case trash
    case downloads
    case developerJunk
}

/// Cleanable item
public struct CleanableItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let size: UInt64
    public let category: CleanupCategory
    public let description: String
    public let lastModified: Date

    public init(id: UUID = UUID(), path: String, size: UInt64,
                category: CleanupCategory, description: String, lastModified: Date) {
        self.id = id
        self.path = path
        self.size = size
        self.category = category
        self.description = description
        self.lastModified = lastModified
    }
}

/// Cleanup result
public struct CleanupResult: Codable, Sendable {
    public let deletedCount: Int
    public let freedSpace: UInt64
    public let errors: [String]

    public init(deletedCount: Int, freedSpace: UInt64, errors: [String]) {
        self.deletedCount = deletedCount
        self.freedSpace = freedSpace
        self.errors = errors
    }
}

/// File entry for disk analysis
public struct FileEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let name: String
    public let size: UInt64
    public let isDirectory: Bool
    public let children: [FileEntry]?

    public init(id: UUID = UUID(), path: String, name: String,
                size: UInt64, isDirectory: Bool, children: [FileEntry]? = nil) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
    }
}

/// Memory information
public struct MemoryInfo: Codable, Sendable {
    public let totalRAM: UInt64
    public let usedRAM: UInt64
    public let activeRAM: UInt64
    public let inactiveRAM: UInt64
    public let wiredRAM: UInt64
    public let compressedRAM: UInt64
    public let memoryPressure: Double // 0.0 - 1.0

    public init(totalRAM: UInt64, usedRAM: UInt64, activeRAM: UInt64,
                inactiveRAM: UInt64, wiredRAM: UInt64, compressedRAM: UInt64,
                memoryPressure: Double) {
        self.totalRAM = totalRAM
        self.usedRAM = usedRAM
        self.activeRAM = activeRAM
        self.inactiveRAM = inactiveRAM
        self.wiredRAM = wiredRAM
        self.compressedRAM = compressedRAM
        self.memoryPressure = memoryPressure
    }
}

/// CPU information
public struct CPUInfo: Codable, Sendable {
    public let coreCount: Int
    public let perCoreUsage: [Double] // 0.0 - 100.0 per core
    public let averageUsage: Double
    public let systemUsage: Double
    public let userUsage: Double

    public init(coreCount: Int, perCoreUsage: [Double], averageUsage: Double,
                systemUsage: Double, userUsage: Double) {
        self.coreCount = coreCount
        self.perCoreUsage = perCoreUsage
        self.averageUsage = averageUsage
        self.systemUsage = systemUsage
        self.userUsage = userUsage
    }
}

/// Memory optimization result
public struct MemoryOptimizationResult: Codable, Sendable {
    public let freedMemory: UInt64
    public let beforePressure: Double
    public let afterPressure: Double

    public init(freedMemory: UInt64, beforePressure: Double, afterPressure: Double) {
        self.freedMemory = freedMemory
        self.beforePressure = beforePressure
        self.afterPressure = afterPressure
    }
}

/// Startup item
public struct StartupItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let path: String
    public let type: StartupItemType
    public let enabled: Bool
    public let isSystemItem: Bool

    public init(id: UUID = UUID(), name: String, path: String,
                type: StartupItemType, enabled: Bool, isSystemItem: Bool) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.enabled = enabled
        self.isSystemItem = isSystemItem
    }
}

/// Startup item type
public enum StartupItemType: String, Codable, Sendable {
    case launchAgent
    case launchDaemon
    case loginItem
}

/// Security threat
public struct SecurityThreat: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let path: String
    public let type: ThreatType
    public let severity: ThreatSeverity
    public let description: String

    public init(id: UUID = UUID(), name: String, path: String,
                type: ThreatType, severity: ThreatSeverity, description: String) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.severity = severity
        self.description = description
    }
}

/// Threat type
public enum ThreatType: String, Codable, Sendable {
    case malware
    case adware
    case suspiciousPersistence
    case browserExtension
}

/// Threat severity
public enum ThreatSeverity: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

/// Maintenance task
public enum MaintenanceTask: String, Codable, Sendable, CaseIterable {
    case rebuildSpotlight
    case rebuildLaunchServices
    case clearDNSCache
    case repairPermissions
    case verifyDisk
}

/// Maintenance result
public struct MaintenanceResult: Codable, Sendable {
    public let completedTasks: [MaintenanceTask]
    public let failedTasks: [MaintenanceTask]
    public let errors: [String]

    public init(completedTasks: [MaintenanceTask], failedTasks: [MaintenanceTask], errors: [String]) {
        self.completedTasks = completedTasks
        self.failedTasks = failedTasks
        self.errors = errors
    }
}

/// Smart Care aggregate result
public struct SmartCareResult: Codable, Sendable {
    public let cleanup: CleanupResult?
    public let memory: MemoryOptimizationResult?
    public let securityThreats: [SecurityThreat]?
    public let totalSpaceFreed: UInt64
    public let totalMemoryFreed: UInt64
    public let threatsRemoved: Int
    public let errors: [String]

    public init(
        cleanup: CleanupResult? = nil,
        memory: MemoryOptimizationResult? = nil,
        securityThreats: [SecurityThreat]? = nil,
        errors: [String] = []
    ) {
        self.cleanup = cleanup
        self.memory = memory
        self.securityThreats = securityThreats
        self.totalSpaceFreed = cleanup?.freedSpace ?? 0
        self.totalMemoryFreed = memory?.freedMemory ?? 0
        self.threatsRemoved = securityThreats?.count ?? 0
        self.errors = errors
    }
}

/// XPC errors
public enum XPCError: Error, Codable, Sendable {
    case connectionFailed
    case unauthorized
    case invalidInput(String)
    case operationFailed(String)
    case pathNotFound(String)
    case permissionDenied(String)

    public var localizedDescription: String {
        switch self {
        case .connectionFailed:
            return "Failed to connect to privileged helper"
        case .unauthorized:
            return "Client is not authorized"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        }
    }
}

// MARK: - Constants

public enum XPCConstants {
    public static let helperMachServiceName = "com.surge.helper"
    public static let helperBundleIdentifier = "com.surge.helper"
    public static let appBundleIdentifier = "com.surge.app"
    public static let quarantineFolderName = ".SURGE-Quarantine"
    public static let version = "0.2.0"
}
