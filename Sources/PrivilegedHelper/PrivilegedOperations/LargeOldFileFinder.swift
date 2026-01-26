//
//  LargeOldFileFinder.swift
//  PrivilegedHelper
//
//  Finds large and old files that may be candidates for cleanup
//

import Foundation
import Shared
import Logging

fileprivate let largeFileLogger = Logger(label: "com.surge.helper.largefile")

class LargeOldFileFinder {

    static let shared = LargeOldFileFinder()

    private init() {}

    /// Find large and old files in given paths
    func findLargeOldFiles(
        in paths: [String],
        minSize: UInt64 = 104_857_600, // 100MB default
        minAge: Int = 365 // 1 year default
    ) throws -> [LargeFileItem] {
        largeFileLogger.info("Starting large/old file scan", metadata: [
            "paths": .stringConvertible(paths.count),
            "minSize": .stringConvertible(minSize),
            "minAge": .stringConvertible(minAge)
        ])

        var largeFiles: [LargeFileItem] = []
        let ageThreshold = Calendar.current.date(byAdding: .day, value: -minAge, to: Date()) ?? Date()

        for pathString in paths {
            guard let sanitizedPath = InputSanitizer.sanitizePath(pathString) else {
                largeFileLogger.warning("Invalid path", metadata: ["path": .string(pathString)])
                continue
            }

            let url = URL(fileURLWithPath: sanitizedPath)
            try scanDirectory(url, minSize: minSize, ageThreshold: ageThreshold, results: &largeFiles)
        }

        // Sort by size descending
        largeFiles.sort { $0.size > $1.size }

        largeFileLogger.info("Large/old file scan complete", metadata: [
            "filesFound": .stringConvertible(largeFiles.count),
            "totalSize": .stringConvertible(largeFiles.reduce(0) { $0 + $1.size })
        ])

        return largeFiles
    }

    // MARK: - Private Methods

    private func scanDirectory(
        _ url: URL,
        minSize: UInt64,
        ageThreshold: Date,
        results: inout [LargeFileItem]
    ) throws {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .contentAccessDateKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .contentAccessDateKey
                ])

                // Only process regular files
                guard resourceValues.isRegularFile == true else { continue }

                // Check size threshold
                guard let fileSize = resourceValues.fileSize,
                      UInt64(fileSize) >= minSize else {
                    continue
                }

                // Check age threshold
                guard let modDate = resourceValues.contentModificationDate,
                      modDate < ageThreshold else {
                    continue
                }

                let item = LargeFileItem(
                    path: fileURL.path,
                    name: fileURL.lastPathComponent,
                    size: UInt64(fileSize),
                    modificationDate: modDate,
                    lastAccessDate: resourceValues.contentAccessDate
                )

                results.append(item)

            } catch {
                // Skip files we can't access
                continue
            }
        }
    }
}
