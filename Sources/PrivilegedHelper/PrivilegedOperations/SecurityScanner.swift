//
//  SecurityScanner.swift
//  PrivilegedHelper
//
//  Scans for malware and security threats using signature-based detection.
//

import Foundation
import Shared
import Logging

fileprivate let securityLogger = Logger(label: "com.surge.helper.security")

class SecurityScanner {

    static let shared = SecurityScanner()

    private let fileManager = FileManager.default
    private let signatureDB = SignatureDatabase.shared
    private let extensionScanner = BrowserExtensionScanner.shared

    // Paths to scan for persistence
    private let persistencePaths = [
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        NSHomeDirectory() + "/Library/LaunchAgents",
        NSHomeDirectory() + "/Library/LaunchDaemons",
        NSHomeDirectory() + "/Library/Application Support",
        "/Library/Application Support",
        NSHomeDirectory() + "/Library/StartupItems",
        "/Library/StartupItems"
    ]

    private init() {}

    // MARK: - Scanning

    func scanForThreats() throws -> [SecurityThreat] {
        securityLogger.info("Starting comprehensive security scan")

        var threats: [SecurityThreat] = []

        // Scan persistence locations with signature matching
        for path in persistencePaths {
            let pathThreats = try scanPersistenceLocation(path)
            threats.append(contentsOf: pathThreats)
        }

        // Scan browser extensions
        let extensionThreats = extensionScanner.scanAllBrowsers()
        threats.append(contentsOf: extensionThreats)

        // Deduplicate threats by path
        threats = Array(Dictionary(grouping: threats, by: { $0.path }).values.compactMap { $0.first })

        securityLogger.info("Security scan complete", metadata: [
            "threats": .stringConvertible(threats.count),
            "persistence": .stringConvertible(threats.filter { $0.type == .suspiciousPersistence || $0.type == .malware }.count),
            "extensions": .stringConvertible(threats.filter { $0.type == .browserExtension }.count)
        ])

        return threats
    }

    private func scanPersistenceLocation(_ path: String) throws -> [SecurityThreat] {
        var threats: [SecurityThreat] = []

        guard fileManager.fileExists(atPath: path) else {
            return threats
        }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)

            for item in contents {
                let itemPath = (path as NSString).appendingPathComponent(item)

                // Skip certain system files
                if shouldSkipFile(item) {
                    continue
                }

                // Check against signature database
                if let threat = checkForThreat(at: itemPath, name: item) {
                    threats.append(threat)
                }
            }
        } catch {
            securityLogger.warning("Failed to scan persistence location", metadata: [
                "path": .string(path),
                "error": .string(error.localizedDescription)
            ])
        }

        return threats
    }

    private func checkForThreat(at path: String, name: String) -> SecurityThreat? {
        // Calculate file hash for signature matching (for files, not directories)
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        var hash: String?
        if !isDirectory.boolValue {
            // Only hash files smaller than 10MB for performance
            if let attributes = try? fileManager.attributesOfItem(atPath: path),
               let fileSize = attributes[.size] as? UInt64,
               fileSize < 10_485_760 {
                hash = signatureDB.calculateFileHash(at: path)
            }
        }

        // Check against signature database
        if let signature = signatureDB.matchFile(path: path, name: name, hash: hash) {
            return SecurityThreat(
                name: signature.name,
                path: path,
                type: parseType(signature.type),
                severity: parseSeverity(signature.severity),
                description: signature.description
            )
        }

        // Heuristic checks for unknown threats
        return heuristicCheck(path: path, name: name)
    }

    private func heuristicCheck(path: String, name: String) -> SecurityThreat? {
        let lowercaseName = name.lowercased()

        // Suspicious naming patterns
        let highRiskPatterns = ["cryptominer", "ransomware", "keylogger", "backdoor"]
        let mediumRiskPatterns = ["adware", "malware", "trojan", "miner", "cryptojack", "adload", "genieo", "bundlore"]
        let lowRiskPatterns = ["suspicious", "unknown", "hidden"]

        for pattern in highRiskPatterns {
            if lowercaseName.contains(pattern) {
                return SecurityThreat(
                    name: name,
                    path: path,
                    type: .malware,
                    severity: .high,
                    description: "Potentially malicious file detected: \(name)"
                )
            }
        }

        for pattern in mediumRiskPatterns {
            if lowercaseName.contains(pattern) {
                return SecurityThreat(
                    name: name,
                    path: path,
                    type: .adware,
                    severity: .medium,
                    description: "Potential adware/malware detected: \(name)"
                )
            }
        }

        for pattern in lowRiskPatterns {
            if lowercaseName.contains(pattern) {
                return SecurityThreat(
                    name: name,
                    path: path,
                    type: .suspiciousPersistence,
                    severity: .low,
                    description: "Suspicious file detected: \(name)"
                )
            }
        }

        // Check for hidden files in suspicious locations
        if name.hasPrefix(".") && !isKnownHiddenFile(name) {
            let parentPath = (path as NSString).deletingLastPathComponent
            if parentPath.contains("Application Support") || parentPath.contains("LaunchAgents") {
                return SecurityThreat(
                    name: name,
                    path: path,
                    type: .suspiciousPersistence,
                    severity: .low,
                    description: "Hidden file in sensitive location: \(name)"
                )
            }
        }

        return nil
    }

    private func shouldSkipFile(_ name: String) -> Bool {
        // Skip known system files
        let knownSystemFiles = [
            "com.apple.",
            ".DS_Store",
            ".localized"
        ]

        for prefix in knownSystemFiles {
            if name.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    private func isKnownHiddenFile(_ name: String) -> Bool {
        let knownHidden = [".DS_Store", ".localized", ".com.apple."]
        return knownHidden.contains { name.hasPrefix($0) }
    }

    // MARK: - Removal

    func removeThreat(_ threat: SecurityThreat) throws {
        securityLogger.info("Removing threat", metadata: [
            "threat": .string(threat.name),
            "type": .string(String(describing: threat.type))
        ])

        guard InputSanitizer.isSafeToDelete(threat.path) else {
            throw XPCError.permissionDenied("Path validation failed for: \(threat.path)")
        }

        // Move to quarantine for safety (allows recovery if false positive)
        _ = try SystemCleaner.shared.deleteFiles(paths: [threat.path], useQuarantine: true)

        securityLogger.info("Threat removed successfully", metadata: [
            "path": .string(threat.path)
        ])
    }

    // MARK: - Helpers

    private func parseType(_ type: String) -> ThreatType {
        switch type.lowercased() {
        case "malware":
            return .malware
        case "adware":
            return .adware
        case "trojan", "suspicious":
            return .suspiciousPersistence
        case "extension":
            return .browserExtension
        default:
            return .suspiciousPersistence
        }
    }

    private func parseSeverity(_ severity: String) -> ThreatSeverity {
        switch severity.lowercased() {
        case "low":
            return .low
        case "medium":
            return .medium
        case "high":
            return .high
        case "critical":
            return .critical
        default:
            return .medium
        }
    }

    // MARK: - Info

    var databaseInfo: (version: String, signatureCount: Int) {
        let info = signatureDB.info
        return (info.version, info.malwareCount + info.extensionCount)
    }
}
