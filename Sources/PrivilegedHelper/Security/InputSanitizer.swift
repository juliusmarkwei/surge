//
//  InputSanitizer.swift
//  PrivilegedHelper
//
//  Sanitizes and validates input from XPC clients to prevent attacks.
//  SECURITY CRITICAL: Prevents path traversal, command injection, etc.
//

import Foundation
import Shared
import Logging

fileprivate let sanitizerLogger = Logger(label: "com.surge.helper.sanitizer")

enum InputSanitizer {

    // MARK: - Protected Paths

    /// Paths that should NEVER be modified or deleted
    private static let blacklistedPaths: Set<String> = [
        "/System",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/usr/lib",
        "/usr/libexec",
        "/Library/Apple",
        "/Library/Frameworks",
        "/Library/Extensions",
        "/private/var/db",
        "/private/var/root",
        "/etc",
        "/dev",
        "/Volumes"
    ]

    /// Paths that are safe to clean (with additional validation)
    private static let whitelistedPaths: Set<String> = [
        "/Library/Caches",
        "/private/var/log",
        "/private/tmp",
        "/Users"  // Will be further validated to user-specific paths
    ]

    // MARK: - Path Validation

    /// Sanitizes and validates a file path
    /// - Parameter path: The path to sanitize
    /// - Returns: The sanitized path, or nil if validation fails
    static func sanitizePath(_ path: String) -> String? {
        // Remove any whitespace
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for empty path
        guard !trimmed.isEmpty else {
            sanitizerLogger.warning("Empty path rejected")
            return nil
        }

        // Resolve to absolute path and standardize
        let url = URL(fileURLWithPath: trimmed)
        let standardized = url.standardized.path

        // Check for path traversal attempts
        if standardized.contains("..") {
            sanitizerLogger.error("Path traversal attempt detected", metadata: ["path": .string(path)])
            return nil
        }

        // Check against blacklist
        for blacklisted in blacklistedPaths {
            if standardized.hasPrefix(blacklisted) {
                sanitizerLogger.error("Blacklisted path rejected", metadata: [
                    "path": .string(standardized),
                    "blacklisted": .string(blacklisted)
                ])
                return nil
            }
        }

        // Additional validation for /Users paths (must be user-owned)
        if standardized.hasPrefix("/Users/") {
            let components = standardized.split(separator: "/")
            if components.count < 2 {
                sanitizerLogger.error("Invalid /Users path", metadata: ["path": .string(standardized)])
                return nil
            }

            // Check that we're not trying to delete the home directory itself
            if components.count == 2 {
                sanitizerLogger.error("Cannot delete user home directory", metadata: ["path": .string(standardized)])
                return nil
            }
        }

        sanitizerLogger.debug("Path validated", metadata: ["path": .string(standardized)])
        return standardized
    }

    /// Validates that a path is safe to delete
    /// - Parameter path: The path to validate
    /// - Returns: true if the path is safe to delete
    static func isSafeToDelete(_ path: String) -> Bool {
        guard let sanitized = sanitizePath(path) else {
            return false
        }

        // Check if path exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sanitized, isDirectory: &isDirectory) else {
            sanitizerLogger.warning("Path does not exist", metadata: ["path": .string(sanitized)])
            return false
        }

        // For directories, extra caution
        if isDirectory.boolValue {
            // Don't delete critical directories
            let criticalDirs = [
                "/Applications",
                "/Library",
                "/System",
                "/Users",
                "/private/var"
            ]

            for critical in criticalDirs {
                if sanitized == critical {
                    sanitizerLogger.error("Cannot delete critical directory", metadata: ["path": .string(sanitized)])
                    return false
                }
            }
        }

        return true
    }

    /// Validates an array of paths
    /// - Parameter paths: The paths to validate
    /// - Returns: Array of sanitized paths, or nil if any path fails validation
    static func sanitizePaths(_ paths: [String]) -> [String]? {
        var sanitized: [String] = []

        for path in paths {
            guard let clean = sanitizePath(path) else {
                return nil
            }
            sanitized.append(clean)
        }

        return sanitized
    }

    // MARK: - String Validation

    /// Sanitizes a string to prevent command injection
    /// - Parameter input: The string to sanitize
    /// - Returns: The sanitized string, or nil if validation fails
    static func sanitizeString(_ input: String) -> String? {
        // Remove control characters
        let sanitized = input.components(separatedBy: .controlCharacters).joined()

        // Check for shell metacharacters (for use in shell commands)
        let dangerous = CharacterSet(charactersIn: "|;&$`<>(){}[]!*?")
        if sanitized.rangeOfCharacter(from: dangerous) != nil {
            sanitizerLogger.warning("Dangerous characters detected in string", metadata: ["input": .string(input)])
            return nil
        }

        return sanitized
    }

    /// Validates that a number is within a safe range
    /// - Parameters:
    ///   - value: The value to validate
    ///   - min: Minimum allowed value
    ///   - max: Maximum allowed value
    /// - Returns: true if the value is within range
    static func validateNumber<T: Comparable>(_ value: T, min: T, max: T) -> Bool {
        value >= min && value <= max
    }
}
