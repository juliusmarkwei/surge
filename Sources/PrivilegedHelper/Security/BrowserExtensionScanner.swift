//
//  BrowserExtensionScanner.swift
//  PrivilegedHelper
//
//  Scans browser extensions for malicious add-ons
//

import Foundation
import Shared
import Logging

fileprivate let extensionLogger = Logger(label: "com.surge.helper.extensions")

struct BrowserExtension {
    let browser: String
    let name: String
    let identifier: String
    let path: String
    let version: String?
    let enabled: Bool
}

class BrowserExtensionScanner {

    static let shared = BrowserExtensionScanner()

    private let fileManager = FileManager.default
    private let homeDir = NSHomeDirectory()

    private init() {}

    // MARK: - Scanning

    func scanAllBrowsers() -> [SecurityThreat] {
        extensionLogger.info("Scanning browser extensions")

        var threats: [SecurityThreat] = []

        // Scan Chrome extensions
        threats.append(contentsOf: scanChromeExtensions())

        // Scan Safari extensions
        threats.append(contentsOf: scanSafariExtensions())

        // Scan Firefox extensions
        threats.append(contentsOf: scanFirefoxExtensions())

        extensionLogger.info("Browser extension scan complete", metadata: [
            "threats": .stringConvertible(threats.count)
        ])

        return threats
    }

    // MARK: - Chrome

    private func scanChromeExtensions() -> [SecurityThreat] {
        var threats: [SecurityThreat] = []

        let chromePaths = [
            homeDir + "/Library/Application Support/Google/Chrome/Default/Extensions",
            homeDir + "/Library/Application Support/Google/Chrome/Profile 1/Extensions"
        ]

        for basePath in chromePaths {
            guard fileManager.fileExists(atPath: basePath) else { continue }

            do {
                let extensionDirs = try fileManager.contentsOfDirectory(atPath: basePath)

                for extensionID in extensionDirs {
                    let extensionPath = (basePath as NSString).appendingPathComponent(extensionID)

                    if let threat = checkChromeExtension(id: extensionID, path: extensionPath) {
                        threats.append(threat)
                    }
                }
            } catch {
                extensionLogger.warning("Failed to scan Chrome extensions", metadata: [
                    "path": .string(basePath),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        return threats
    }

    private func checkChromeExtension(id: String, path: String) -> SecurityThreat? {
        // Check against signature database
        if let signature = SignatureDatabase.shared.matchExtension(extensionID: id, browser: "chrome") {
            return SecurityThreat(
                name: signature.name,
                path: path,
                type: .browserExtension,
                severity: parseSeverity(signature.severity),
                description: signature.description
            )
        }

        // Check for suspicious patterns
        if isSuspiciousExtensionID(id) {
            return SecurityThreat(
                name: "Suspicious Chrome Extension",
                path: path,
                type: .browserExtension,
                severity: .low,
                description: "Extension with suspicious identifier pattern: \(id)"
            )
        }

        return nil
    }

    // MARK: - Safari

    private func scanSafariExtensions() -> [SecurityThreat] {
        var threats: [SecurityThreat] = []

        let safariPaths = [
            homeDir + "/Library/Safari/Extensions",
            "/Library/Safari/Extensions"
        ]

        for basePath in safariPaths {
            guard fileManager.fileExists(atPath: basePath) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(atPath: basePath)

                for item in contents where item.hasSuffix(".safariextz") || item.hasSuffix(".appex") {
                    let extensionPath = (basePath as NSString).appendingPathComponent(item)

                    if let threat = checkSafariExtension(name: item, path: extensionPath) {
                        threats.append(threat)
                    }
                }
            } catch {
                extensionLogger.warning("Failed to scan Safari extensions", metadata: [
                    "path": .string(basePath),
                    "error": .string(error.localizedDescription)
                ])
            }
        }

        return threats
    }

    private func checkSafariExtension(name: String, path: String) -> SecurityThreat? {
        // Check for suspicious naming patterns
        let suspiciousPatterns = ["adware", "malware", "inject", "hijack"]

        let lowercaseName = name.lowercased()
        for pattern in suspiciousPatterns {
            if lowercaseName.contains(pattern) {
                return SecurityThreat(
                    name: "Suspicious Safari Extension",
                    path: path,
                    type: .browserExtension,
                    severity: .medium,
                    description: "Safari extension with suspicious name: \(name)"
                )
            }
        }

        return nil
    }

    // MARK: - Firefox

    private func scanFirefoxExtensions() -> [SecurityThreat] {
        var threats: [SecurityThreat] = []

        // Firefox uses a different structure with profile directories
        let firefoxBasePath = homeDir + "/Library/Application Support/Firefox/Profiles"

        guard fileManager.fileExists(atPath: firefoxBasePath) else {
            return threats
        }

        do {
            let profiles = try fileManager.contentsOfDirectory(atPath: firefoxBasePath)

            for profile in profiles {
                let extensionsPath = (firefoxBasePath as NSString)
                    .appendingPathComponent(profile)
                    .appending("/extensions")

                if fileManager.fileExists(atPath: extensionsPath) {
                    let extensions = try fileManager.contentsOfDirectory(atPath: extensionsPath)

                    for extensionFile in extensions where extensionFile.hasSuffix(".xpi") {
                        let fullPath = (extensionsPath as NSString).appendingPathComponent(extensionFile)

                        if let threat = checkFirefoxExtension(name: extensionFile, path: fullPath) {
                            threats.append(threat)
                        }
                    }
                }
            }
        } catch {
            extensionLogger.warning("Failed to scan Firefox extensions", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }

        return threats
    }

    private func checkFirefoxExtension(name: String, path: String) -> SecurityThreat? {
        // Similar suspicious pattern checking
        let suspiciousPatterns = ["adware", "malware", "inject"]

        let lowercaseName = name.lowercased()
        for pattern in suspiciousPatterns {
            if lowercaseName.contains(pattern) {
                return SecurityThreat(
                    name: "Suspicious Firefox Extension",
                    path: path,
                    type: .browserExtension,
                    severity: .medium,
                    description: "Firefox extension with suspicious name: \(name)"
                )
            }
        }

        return nil
    }

    // MARK: - Helpers

    private func isSuspiciousExtensionID(_ id: String) -> Bool {
        // Chrome extension IDs are 32-character lowercase hex strings
        // Randomly generated IDs are more suspicious than known publisher IDs
        guard id.count == 32 else { return false }

        // Check if it's all random characters (heuristic)
        let hexCharSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        let idCharSet = CharacterSet(charactersIn: id.lowercased())

        return hexCharSet.isSuperset(of: idCharSet)
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
}
