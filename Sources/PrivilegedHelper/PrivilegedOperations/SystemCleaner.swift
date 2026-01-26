//
//  SystemCleaner.swift
//  PrivilegedHelper
//
//  Handles system cleanup operations (cache deletion, log cleanup, etc.).
//

import Foundation
import Shared
import Logging

fileprivate let cleanerLogger = Logger(label: "com.surge.helper.cleaner")

class SystemCleaner {

    static let shared = SystemCleaner()

    private let fileManager = FileManager.default
    private let quarantinePath: String

    private init() {
        // Create quarantine folder in /tmp
        quarantinePath = "/tmp/\(XPCConstants.quarantineFolderName)"
        try? fileManager.createDirectory(atPath: quarantinePath, withIntermediateDirectories: true)
    }

    // MARK: - Scanning

    func scanCleanableFiles(categories: [CleanupCategory]) throws -> [CleanableItem] {
        var items: [CleanableItem] = []

        for category in categories {
            let categoryItems = try scanCategory(category)
            items.append(contentsOf: categoryItems)
        }

        cleanerLogger.info("Scan complete", metadata: [
            "categories": .stringConvertible(categories.count),
            "items": .stringConvertible(items.count)
        ])

        return items
    }

    private func scanCategory(_ category: CleanupCategory) throws -> [CleanableItem] {
        let paths = pathsForCategory(category)
        var items: [CleanableItem] = []

        for path in paths {
            guard let sanitized = InputSanitizer.sanitizePath(path) else {
                cleanerLogger.warning("Skipping invalid path", metadata: ["path": .string(path)])
                continue
            }

            let categoryItems = try scanDirectory(
                at: sanitized,
                category: category,
                recursive: true
            )
            items.append(contentsOf: categoryItems)
        }

        return items
    }

    private func pathsForCategory(_ category: CleanupCategory) -> [String] {
        let homeDir = NSHomeDirectory()

        switch category {
        case .systemCaches:
            return [
                "/Library/Caches",
                "/System/Library/Caches"
            ]
        case .userCaches:
            return [
                homeDir + "/Library/Caches"
            ]
        case .logs:
            return [
                "/private/var/log",
                homeDir + "/Library/Logs",
                "/Library/Logs"
            ]
        case .trash:
            return [
                homeDir + "/.Trash"
            ]
        case .downloads:
            return [
                homeDir + "/Downloads"
            ]
        case .developerJunk:
            var paths = [
                homeDir + "/Library/Developer/Xcode/DerivedData",
                homeDir + "/Library/Developer/Xcode/iOS DeviceSupport",
                homeDir + "/Library/Developer/CoreSimulator/Caches"
            ]

            // Add common developer tool caches if they exist
            let optionalPaths = [
                homeDir + "/.npm",
                homeDir + "/.yarn/cache",
                homeDir + "/.cargo/registry",
                homeDir + "/.gradle/caches",
                homeDir + "/Library/Caches/Homebrew",
                homeDir + "/Library/Caches/CocoaPods",
                homeDir + "/Library/Caches/pip",
                homeDir + "/.cache" // Generic cache dir
            ]

            for path in optionalPaths {
                if fileManager.fileExists(atPath: path) {
                    paths.append(path)
                }
            }

            return paths
        }
    }

    private func scanDirectory(
        at path: String,
        category: CleanupCategory,
        recursive: Bool
    ) throws -> [CleanableItem] {
        var items: [CleanableItem] = []

        guard fileManager.fileExists(atPath: path) else {
            cleanerLogger.debug("Path does not exist, skipping", metadata: ["path": .string(path)])
            return items
        }

        // Special handling for protected system directories
        if path.hasPrefix("/System/") || path.hasPrefix("/Library/Application Support/") {
            cleanerLogger.debug("Skipping protected system path", metadata: ["path": .string(path)])
            return items
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            cleanerLogger.warning("Cannot read directory", metadata: ["path": .string(path)])
            return items
        }

        for item in contents {
            // Skip hidden files (except .Trash and .npm, etc.)
            if item.hasPrefix(".") && !allowedHiddenPrefixes.contains(where: { item.hasPrefix($0) }) {
                continue
            }

            let itemPath = (path as NSString).appendingPathComponent(item)

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) else {
                continue
            }

            // Get file attributes
            guard let attributes = try? fileManager.attributesOfItem(atPath: itemPath) else {
                continue
            }

            let modificationDate = attributes[.modificationDate] as? Date ?? Date.distantPast

            // Skip files modified in the last 7 days (safety measure)
            let daysSinceModification = -modificationDate.timeIntervalSinceNow / (24 * 60 * 60)
            if daysSinceModification < 7 {
                continue
            }

            // Calculate size
            let totalSize: UInt64
            if isDirectory.boolValue {
                // For directories, calculate total recursive size
                totalSize = try directorySize(at: itemPath)
            } else {
                totalSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            }

            // Only include items larger than 1KB
            guard totalSize > 1024 else {
                continue
            }

            // For certain categories, we want to list directory contents instead of the directory itself
            if isDirectory.boolValue && shouldScanRecursively(category: category, item: item) {
                let subItems = try scanDirectory(
                    at: itemPath,
                    category: category,
                    recursive: false
                )
                items.append(contentsOf: subItems)
            } else {
                // Add as a single item
                let cleanableItem = CleanableItem(
                    path: itemPath,
                    size: totalSize,
                    category: category,
                    description: descriptionForItem(item, category: category, path: itemPath),
                    lastModified: modificationDate
                )

                items.append(cleanableItem)
            }
        }

        return items
    }

    private let allowedHiddenPrefixes = [".Trash", ".npm", ".yarn", ".cargo", ".gradle", ".cache"]

    private func shouldScanRecursively(category: CleanupCategory, item: String) -> Bool {
        // For caches, scan one level deeper to show individual app caches
        if category == .systemCaches || category == .userCaches {
            return true
        }

        // For developer junk, show top-level items
        if category == .developerJunk {
            return false
        }

        return false
    }

    private func directorySize(at path: String) throws -> UInt64 {
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return 0
        }

        for case let file as String in enumerator {
            let filePath = (path as NSString).appendingPathComponent(file)

            if let attributes = try? fileManager.attributesOfItem(atPath: filePath) {
                totalSize += (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            }
        }

        return totalSize
    }

    private func descriptionForItem(_ name: String, category: CleanupCategory, path: String) -> String {
        switch category {
        case .systemCaches:
            if path.contains("com.apple.") {
                return "System cache (Apple)"
            }
            return "System cache"

        case .userCaches:
            // Extract app identifier from path
            if let bundleId = extractBundleIdentifier(from: path) {
                return "App cache: \(bundleId)"
            }
            return "Application cache"

        case .logs:
            if name.hasSuffix(".log") {
                return "Log file"
            } else if name.hasSuffix(".log.gz") || name.hasSuffix(".log.zip") {
                return "Compressed log"
            }
            return "Log data"

        case .trash:
            return "Trashed item"

        case .downloads:
            let ext = (name as NSString).pathExtension.lowercased()
            switch ext {
            case "dmg": return "Disk image"
            case "zip", "tar", "gz", "rar": return "Archive"
            case "pdf": return "PDF document"
            case "jpg", "jpeg", "png", "gif": return "Image"
            default: return "Downloaded file"
            }

        case .developerJunk:
            if path.contains("DerivedData") {
                return "Xcode build cache"
            } else if path.contains("DeviceSupport") {
                return "iOS device support files"
            } else if path.contains("Simulator") {
                return "Simulator cache"
            } else if path.contains(".npm") {
                return "npm package cache"
            } else if path.contains(".yarn") {
                return "Yarn package cache"
            } else if path.contains(".cargo") {
                return "Rust package cache"
            } else if path.contains("Homebrew") {
                return "Homebrew cache"
            } else if path.contains("CocoaPods") {
                return "CocoaPods cache"
            }
            return "Developer cache"
        }
    }

    private func extractBundleIdentifier(from path: String) -> String? {
        let components = path.split(separator: "/")
        if let cacheIndex = components.firstIndex(of: "Caches"),
           cacheIndex + 1 < components.count {
            let identifier = String(components[cacheIndex + 1])
            // Clean up the identifier for display
            if identifier.contains(".") {
                return identifier
            }
        }
        return nil
    }

    // MARK: - Deletion

    func deleteFiles(paths: [String], useQuarantine: Bool) throws -> CleanupResult {
        var deletedCount = 0
        var freedSpace: UInt64 = 0
        var errors: [String] = []

        for path in paths {
            // Double-check safety
            guard InputSanitizer.isSafeToDelete(path) else {
                errors.append("Unsafe path rejected: \(path)")
                cleanerLogger.error("Unsafe deletion attempt", metadata: ["path": .string(path)])
                continue
            }

            // Get size before deletion
            if let attributes = try? fileManager.attributesOfItem(atPath: path) {
                let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
                freedSpace += size
            }

            do {
                if useQuarantine {
                    try moveToQuarantine(path)
                } else {
                    try fileManager.removeItem(atPath: path)
                }

                deletedCount += 1
                cleanerLogger.debug("Deleted", metadata: ["path": .string(path)])

            } catch {
                let errorMsg = "Failed to delete \(path): \(error.localizedDescription)"
                errors.append(errorMsg)
                cleanerLogger.error("Deletion failed", metadata: [
                    "path": .string(path),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        return CleanupResult(
            deletedCount: deletedCount,
            freedSpace: freedSpace,
            errors: errors
        )
    }

    private func moveToQuarantine(_ path: String) throws {
        let filename = (path as NSString).lastPathComponent
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantinedPath = (quarantinePath as NSString)
            .appendingPathComponent("\(timestamp)_\(filename)")

        try fileManager.moveItem(atPath: path, toPath: quarantinedPath)

        cleanerLogger.info("Moved to quarantine", metadata: [
            "from": .string(path),
            "to": .string(quarantinedPath)
        ])
    }

    // MARK: - Quarantine Management

    func cleanupQuarantine(olderThanDays days: Int = 30) throws {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)

        guard let contents = try? fileManager.contentsOfDirectory(atPath: quarantinePath) else {
            return
        }

        for item in contents {
            let itemPath = (quarantinePath as NSString).appendingPathComponent(item)

            if let attributes = try? fileManager.attributesOfItem(atPath: itemPath),
               let modDate = attributes[.modificationDate] as? Date,
               modDate < cutoffDate {

                try? fileManager.removeItem(atPath: itemPath)
                cleanerLogger.info("Cleaned old quarantine item", metadata: ["path": .string(itemPath)])
            }
        }
    }
}
