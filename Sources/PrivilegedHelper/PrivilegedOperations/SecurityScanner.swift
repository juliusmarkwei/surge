//
//  SecurityScanner.swift
//  PrivilegedHelper
//
//  Scans for malware and security threats.
//

import Foundation
import Shared
import Logging

fileprivate let securityLogger = Logger(label: "com.surge.helper.security")

class SecurityScanner {

    static let shared = SecurityScanner()

    private let fileManager = FileManager.default

    // Paths to scan for persistence
    private let persistencePaths = [
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        NSHomeDirectory() + "/Library/LaunchAgents",
        NSHomeDirectory() + "/Library/Application Support",
        "/Library/Application Support"
    ]

    private init() {}

    // MARK: - Scanning

    func scanForThreats() throws -> [SecurityThreat] {
        securityLogger.info("Starting security scan")

        var threats: [SecurityThreat] = []

        // Scan persistence locations
        for path in persistencePaths {
            let pathThreats = try scanPersistenceLocation(path)
            threats.append(contentsOf: pathThreats)
        }

        securityLogger.info("Security scan complete", metadata: [
            "threats": .stringConvertible(threats.count)
        ])

        return threats
    }

    private func scanPersistenceLocation(_ path: String) throws -> [SecurityThreat] {
        var threats: [SecurityThreat] = []

        guard fileManager.fileExists(atPath: path) else {
            return threats
        }

        let contents = try fileManager.contentsOfDirectory(atPath: path)

        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)

            // Check against known threat patterns
            if let threat = checkForThreat(at: itemPath, name: item) {
                threats.append(threat)
            }
        }

        return threats
    }

    private func checkForThreat(at path: String, name: String) -> SecurityThreat? {
        // Placeholder for signature-based detection
        // In a real implementation, this would check against a database of malware signatures

        // Example: Check for suspicious naming patterns
        let suspiciousPatterns = [
            "adware",
            "malware",
            "trojan",
            "miner",
            "cryptojack"
        ]

        let lowercaseName = name.lowercased()
        for pattern in suspiciousPatterns {
            if lowercaseName.contains(pattern) {
                return SecurityThreat(
                    name: name,
                    path: path,
                    type: .suspiciousPersistence,
                    severity: .medium,
                    description: "Suspicious persistence item detected: \(name)"
                )
            }
        }

        return nil
    }

    // MARK: - Removal

    func removeThreat(_ threat: SecurityThreat) throws {
        securityLogger.info("Removing threat", metadata: ["threat": .string(threat.name)])

        guard InputSanitizer.isSafeToDelete(threat.path) else {
            throw NSError(domain: "SecurityScanner", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Path validation failed"
            ])
        }

        // Move to quarantine for safety
        try SystemCleaner.shared.deleteFiles(paths: [threat.path], useQuarantine: true)

        securityLogger.info("Threat removed successfully")
    }
}
