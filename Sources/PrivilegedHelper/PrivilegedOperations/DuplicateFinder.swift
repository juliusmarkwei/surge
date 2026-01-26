//
//  DuplicateFinder.swift
//  PrivilegedHelper
//
//  Finds duplicate files using SHA-256 content hashing
//

import Foundation
import Shared
import Logging
import CryptoKit

fileprivate let duplicateLogger = Logger(label: "com.surge.helper.duplicates")

class DuplicateFinder {

    static let shared = DuplicateFinder()

    private init() {}

    /// Find duplicate files in given paths
    func findDuplicates(in paths: [String], minSize: UInt64 = 1_048_576) throws -> [DuplicateGroup] {
        duplicateLogger.info("Starting duplicate scan", metadata: [
            "paths": .stringConvertible(paths.count),
            "minSize": .stringConvertible(minSize)
        ])

        var filesBySize: [UInt64: [URL]] = [:]
        var hashToFiles: [String: [DuplicateFile]] = [:]

        // Step 1: Group files by size (quick pre-filter)
        for pathString in paths {
            guard let sanitizedPath = InputSanitizer.sanitizePath(pathString) else {
                duplicateLogger.warning("Invalid path", metadata: ["path": .string(pathString)])
                continue
            }

            let url = URL(fileURLWithPath: sanitizedPath)
            try scanDirectory(url, minSize: minSize, filesBySize: &filesBySize)
        }

        duplicateLogger.info("Grouped files by size", metadata: [
            "uniqueSizes": .stringConvertible(filesBySize.count)
        ])

        // Step 2: Hash files with same size
        for (size, urls) in filesBySize where urls.count > 1 {
            for url in urls {
                do {
                    let hash = try hashFile(at: url)
                    let file = DuplicateFile(
                        path: url.path,
                        name: url.lastPathComponent,
                        size: size,
                        modificationDate: try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
                    )

                    hashToFiles[hash, default: []].append(file)
                } catch {
                    duplicateLogger.warning("Failed to hash file", metadata: [
                        "path": .string(url.path),
                        "error": .string(error.localizedDescription)
                    ])
                }
            }
        }

        // Step 3: Create duplicate groups (only groups with 2+ files)
        let duplicateGroups = hashToFiles
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(hash: $0.key, files: $0.value) }
            .sorted { $0.wastedSpace > $1.wastedSpace }

        duplicateLogger.info("Found duplicate groups", metadata: [
            "groups": .stringConvertible(duplicateGroups.count),
            "totalWasted": .stringConvertible(duplicateGroups.reduce(0) { $0 + $1.wastedSpace })
        ])

        return duplicateGroups
    }

    // MARK: - Private Methods

    private func scanDirectory(_ url: URL, minSize: UInt64, filesBySize: inout [UInt64: [URL]]) throws {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])

                guard resourceValues.isRegularFile == true,
                      let fileSize = resourceValues.fileSize,
                      UInt64(fileSize) >= minSize else {
                    continue
                }

                filesBySize[UInt64(fileSize), default: []].append(fileURL)
            } catch {
                // Skip files we can't access
                continue
            }
        }
    }

    private func hashFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024 // 1MB buffer

        while autoreleasepool(invoking: {
            guard let data = try? handle.read(upToCount: bufferSize), !data.isEmpty else {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
