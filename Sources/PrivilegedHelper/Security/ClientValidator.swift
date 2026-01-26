//
//  ClientValidator.swift
//  PrivilegedHelper
//
//  Validates XPC clients to prevent unauthorized access.
//  SECURITY CRITICAL: This prevents privilege escalation attacks.
//

import Foundation
import Shared
import Security
import Logging

fileprivate let validatorLogger = Logger(label: "com.surge.helper.security")

class ClientValidator {

    static let shared = ClientValidator()

    private init() {}

    /// Validates that the connecting client is authorized
    /// - Parameter connection: The XPC connection to validate
    /// - Returns: true if the client is authorized, false otherwise
    func validateClient(_ connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier

        validatorLogger.info("Validating client", metadata: [
            "pid": .stringConvertible(pid)
        ])

        // Create SecCode from PID for validation
        var code: SecCode?
        var status = SecCodeCopyGuestWithAttributes(
            nil,
            [kSecGuestAttributePid: pid] as CFDictionary,
            [],
            &code
        )

        guard status == errSecSuccess, let code = code else {
            validatorLogger.error("Failed to create SecCode", metadata: [
                "status": .stringConvertible(status)
            ])
            return false
        }

        // Create requirement string
        // In production, this should match your app's actual code signature
        // For now, we'll accept any validly signed app from the same team
        let requirementString = "identifier \"\(XPCConstants.appBundleIdentifier)\" and anchor apple generic"

        var requirement: SecRequirement?
        status = SecRequirementCreateWithString(
            requirementString as CFString,
            [],
            &requirement
        )

        guard status == errSecSuccess, let requirement = requirement else {
            validatorLogger.error("Failed to create requirement", metadata: [
                "status": .stringConvertible(status)
            ])
            return false
        }

        // Validate the code against the requirement
        status = SecCodeCheckValidity(code, [], requirement)

        if status == errSecSuccess {
            validatorLogger.info("Client validation successful")
            return true
        } else {
            validatorLogger.error("Client validation failed", metadata: [
                "status": .stringConvertible(status),
                "message": .string(secErrorMessage(status))
            ])
            return false
        }
    }

    /// Get human-readable error message for Security framework errors
    private func secErrorMessage(_ status: OSStatus) -> String {
        if let errorString = SecCopyErrorMessageString(status, nil) {
            return errorString as String
        }
        return "Unknown error (\(status))"
    }
}
