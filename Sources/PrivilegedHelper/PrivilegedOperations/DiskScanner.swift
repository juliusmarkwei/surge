//
//  DiskScanner.swift
//  PrivilegedHelper
//
//  Scans directory trees for disk space analysis.
//

import Foundation
import Shared
import Logging

fileprivate let scannerLogger = Logger(label: "com.surge.helper.diskscanner")

class DiskScanner {

    static let shared = DiskScanner()

    private let fileManager = FileManager.default

    private init() {}

    func scanDirectory(at path: String, maxDepth: Int) throws -> [FileEntry] {
        scannerLogger.info("Starting disk scan", metadata: [
            "path": .string(path),
            "maxDepth": .stringConvertible(maxDepth)
        ])

        let rootEntry = try scanEntry(at: path, currentDepth: 0, maxDepth: maxDepth)

        return rootEntry.children ?? []
    }

    private func scanEntry(
        at path: String,
        currentDepth: Int,
        maxDepth: Int
    ) throws -> FileEntry {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw NSError(domain: "DiskScanner", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Path does not exist: \(path)"
            ])
        }

        let name = (path as NSString).lastPathComponent

        if !isDirectory.boolValue {
            // File - get size and return
            let attributes = try fileManager.attributesOfItem(atPath: path)
            let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0

            return FileEntry(
                path: path,
                name: name,
                size: size,
                isDirectory: false,
                children: nil
            )
        }

        // Directory
        var children: [FileEntry] = []
        var totalSize: UInt64 = 0

        if currentDepth < maxDepth {
            // Scan children
            let contents = try fileManager.contentsOfDirectory(atPath: path)

            for item in contents {
                // Skip hidden files (except at root level)
                if currentDepth > 0 && item.hasPrefix(".") {
                    continue
                }

                let itemPath = (path as NSString).appendingPathComponent(item)

                do {
                    let childEntry = try scanEntry(
                        at: itemPath,
                        currentDepth: currentDepth + 1,
                        maxDepth: maxDepth
                    )

                    children.append(childEntry)
                    totalSize += childEntry.size

                } catch {
                    // Skip items we can't access
                    scannerLogger.debug("Skipping inaccessible item", metadata: [
                        "path": .string(itemPath),
                        "error": .string(error.localizedDescription)
                    ])
                }
            }

            // Sort children by size (largest first)
            children.sort { $0.size > $1.size }
        } else {
            // Max depth reached - calculate size only
            totalSize = try calculateDirectorySize(at: path)
        }

        return FileEntry(
            path: path,
            name: name,
            size: totalSize,
            isDirectory: true,
            children: children.isEmpty ? nil : children
        )
    }

    private func calculateDirectorySize(at path: String) throws -> UInt64 {
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])

                if let isRegularFile = resourceValues.isRegularFile, isRegularFile,
                   let fileSize = resourceValues.fileSize {
                    totalSize += UInt64(fileSize)
                }
            } catch {
                // Skip files we can't access
                continue
            }
        }

        return totalSize
    }
}
