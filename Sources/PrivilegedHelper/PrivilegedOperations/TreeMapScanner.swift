//
//  TreeMapScanner.swift
//  PrivilegedHelper
//
//  Scans directory tree for TreeMap visualization
//

import Foundation
import Shared
import Logging

fileprivate let treeMapLogger = Logger(label: "com.surge.helper.treemap")

class TreeMapScanner {

    static let shared = TreeMapScanner()

    private init() {}

    /// Scan directory tree and build TreeMapItem hierarchy
    func scanTreeMap(
        at path: String,
        maxDepth: Int = 5
    ) throws -> TreeMapItem {
        guard let sanitizedPath = InputSanitizer.sanitizePath(path) else {
            throw XPCError.invalidInput("Invalid path: \(path)")
        }

        treeMapLogger.info("Starting TreeMap scan", metadata: [
            "path": .string(sanitizedPath),
            "maxDepth": .stringConvertible(maxDepth)
        ])

        let url = URL(fileURLWithPath: sanitizedPath)

        guard FileManager.default.fileExists(atPath: sanitizedPath) else {
            throw XPCError.pathNotFound(sanitizedPath)
        }

        let item = try scanItem(at: url, currentDepth: 0, maxDepth: maxDepth)

        treeMapLogger.info("TreeMap scan complete", metadata: [
            "totalSize": .stringConvertible(item.size)
        ])

        return item
    }

    // MARK: - Private Methods

    private func scanItem(at url: URL, currentDepth: Int, maxDepth: Int) throws -> TreeMapItem {
        let fileManager = FileManager.default
        let resourceValues = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey
        ])

        let isDirectory = resourceValues.isDirectory ?? false
        let name = url.lastPathComponent
        let modDate = resourceValues.contentModificationDate

        if isDirectory {
            // Scan directory contents
            var children: [TreeMapItem] = []
            var totalSize: UInt64 = 0

            // Only scan children if we haven't reached max depth
            if currentDepth < maxDepth {
                do {
                    let contents = try fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                        options: [.skipsHiddenFiles]
                    )

                    for childURL in contents {
                        do {
                            let childItem = try scanItem(
                                at: childURL,
                                currentDepth: currentDepth + 1,
                                maxDepth: maxDepth
                            )
                            children.append(childItem)
                            totalSize += childItem.size
                        } catch {
                            // Skip items we can't access
                            continue
                        }
                    }

                    // Sort children by size descending
                    children.sort { $0.size > $1.size }

                } catch {
                    treeMapLogger.warning("Failed to scan directory", metadata: [
                        "path": .string(url.path),
                        "error": .string(error.localizedDescription)
                    ])
                }
            } else {
                // At max depth, just calculate size without children
                totalSize = calculateDirectorySize(at: url)
            }

            return TreeMapItem(
                path: url.path,
                name: name,
                size: totalSize,
                isDirectory: true,
                children: children.isEmpty ? nil : children,
                modificationDate: modDate
            )

        } else {
            // Regular file
            let fileSize = UInt64(resourceValues.fileSize ?? 0)

            return TreeMapItem(
                path: url.path,
                name: name,
                size: fileSize,
                isDirectory: false,
                children: nil,
                modificationDate: modDate
            )
        }
    }

    /// Calculate total size of directory (without building child tree)
    private func calculateDirectorySize(at url: URL) -> UInt64 {
        var totalSize: UInt64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += UInt64(values.fileSize ?? 0)
            } catch {
                continue
            }
        }

        return totalSize
    }
}
