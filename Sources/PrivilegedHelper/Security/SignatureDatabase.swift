//
//  SignatureDatabase.swift
//  PrivilegedHelper
//
//  Malware signature database for detection
//

import Foundation
import Shared
import Logging
import CryptoKit

fileprivate let sigLogger = Logger(label: "com.surge.helper.signatures")

/// Malware signature entry
struct MalwareSignature: Codable {
    let id: String
    let name: String
    let type: String // malware, adware, trojan, etc.
    let severity: String // low, medium, high, critical
    let description: String
    let sha256Hashes: [String]?
    let pathPatterns: [String]?
    let namePatterns: [String]?
    let bundleIdentifiers: [String]?
    let dateAdded: String
    let references: [String]?
}

/// Browser extension signature
struct ExtensionSignature: Codable {
    let id: String
    let name: String
    let description: String
    let severity: String
    let extensionIDs: [String]
    let browsers: [String] // safari, chrome, firefox
    let references: [String]?
}

/// Signature database container
struct SignatureContainer: Codable {
    let version: String
    let lastUpdated: String
    let malware: [MalwareSignature]
    let extensions: [ExtensionSignature]
}

class SignatureDatabase {

    static let shared = SignatureDatabase()

    private var malwareSignatures: [MalwareSignature] = []
    private var extensionSignatures: [ExtensionSignature] = []
    private var signatureVersion: String = "unknown"

    private init() {
        loadSignatures()
    }

    // MARK: - Loading

    func loadSignatures() {
        sigLogger.info("Loading signature database")

        // Try to load from Resources bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            sigLogger.warning("Could not find resource path")
            loadDefaultSignatures()
            return
        }

        let signaturesPath = (bundlePath as NSString).appendingPathComponent("signatures.json")

        guard FileManager.default.fileExists(atPath: signaturesPath) else {
            sigLogger.warning("Signatures file not found, using defaults")
            loadDefaultSignatures()
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: signaturesPath))
            let container = try JSONDecoder().decode(SignatureContainer.self, from: data)

            malwareSignatures = container.malware
            extensionSignatures = container.extensions
            signatureVersion = container.version

            sigLogger.info("Loaded signatures", metadata: [
                "version": .string(signatureVersion),
                "malware": .stringConvertible(malwareSignatures.count),
                "extensions": .stringConvertible(extensionSignatures.count)
            ])
        } catch {
            sigLogger.error("Failed to load signatures", metadata: [
                "error": .string(error.localizedDescription)
            ])
            loadDefaultSignatures()
        }
    }

    private func loadDefaultSignatures() {
        sigLogger.info("Loading default signatures")

        // Default malware signatures (known macOS threats)
        malwareSignatures = [
            MalwareSignature(
                id: "adload",
                name: "Adload Adware",
                type: "adware",
                severity: "medium",
                description: "Adware that injects advertisements into web browsers",
                sha256Hashes: nil,
                pathPatterns: [
                    "*/Library/LaunchAgents/com.*.plist",
                    "*/Library/Application Support/.*"
                ],
                namePatterns: ["adload", "searchbaron", "safefinder"],
                bundleIdentifiers: nil,
                dateAdded: "2025-01-26",
                references: ["https://www.malwarebytes.com/mac-adload"]
            ),
            MalwareSignature(
                id: "genio",
                name: "Genio Adware",
                type: "adware",
                severity: "medium",
                description: "Adware that modifies browser settings and displays ads",
                sha256Hashes: nil,
                pathPatterns: nil,
                namePatterns: ["genio", "genieo"],
                bundleIdentifiers: ["com.genieo.*"],
                dateAdded: "2025-01-26",
                references: nil
            ),
            MalwareSignature(
                id: "shlayer",
                name: "Shlayer Trojan",
                type: "malware",
                severity: "high",
                description: "Trojan that downloads additional malware",
                sha256Hashes: nil,
                pathPatterns: nil,
                namePatterns: ["shlayer", "bundlore"],
                bundleIdentifiers: nil,
                dateAdded: "2025-01-26",
                references: ["https://www.carbonblack.com/blog/shlayer-macos-malware/"]
            ),
            MalwareSignature(
                id: "xcsset",
                name: "XCSSET Malware",
                type: "malware",
                severity: "critical",
                description: "Malware targeting Xcode projects and stealing credentials",
                sha256Hashes: nil,
                pathPatterns: ["*/Library/LaunchAgents/*.agent"],
                namePatterns: ["xcsset"],
                bundleIdentifiers: nil,
                dateAdded: "2025-01-26",
                references: nil
            )
        ]

        // Default browser extension signatures
        extensionSignatures = [
            ExtensionSignature(
                id: "fake-adblocker",
                name: "Fake Ad Blocker Extensions",
                description: "Malicious extensions disguised as ad blockers",
                severity: "medium",
                extensionIDs: [],
                browsers: ["chrome", "safari"],
                references: nil
            )
        ]

        signatureVersion = "1.0.0-default"
    }

    // MARK: - Matching

    func matchFile(path: String, name: String, hash: String?) -> MalwareSignature? {
        for signature in malwareSignatures {
            // Check hash match (most reliable)
            if let hash = hash,
               let hashes = signature.sha256Hashes,
               hashes.contains(hash) {
                return signature
            }

            // Check name pattern match
            if let namePatterns = signature.namePatterns {
                let lowercaseName = name.lowercased()
                for pattern in namePatterns {
                    if lowercaseName.contains(pattern.lowercased()) {
                        return signature
                    }
                }
            }

            // Check path pattern match (glob-style)
            if let pathPatterns = signature.pathPatterns {
                for pattern in pathPatterns {
                    if matchesPattern(path: path, pattern: pattern) {
                        return signature
                    }
                }
            }
        }

        return nil
    }

    func matchExtension(extensionID: String, browser: String) -> ExtensionSignature? {
        for signature in extensionSignatures {
            if signature.browsers.contains(browser.lowercased()) &&
               signature.extensionIDs.contains(extensionID) {
                return signature
            }
        }
        return nil
    }

    private func matchesPattern(path: String, pattern: String) -> Bool {
        // Simple glob matching (* wildcard)
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }

        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, options: [], range: range) != nil
    }

    // MARK: - Hash Calculation

    func calculateFileHash(at path: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return nil
        }

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

    // MARK: - Info

    var info: (version: String, malwareCount: Int, extensionCount: Int) {
        (signatureVersion, malwareSignatures.count, extensionSignatures.count)
    }
}
