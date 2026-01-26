//
//  SmartCareViewModel.swift
//  SURGE
//
//  ViewModel for Smart Care (one-click optimization).
//

import Foundation
import SwiftUI
import Shared

@MainActor
class SmartCareViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentTask: String = ""
    @Published var currentDetail: String = ""
    @Published var smartCareResult: SmartCareResult?
    @Published var lastRunDate: Date?
    @Published var error: String?
    @Published var showOnboarding: Bool = false

    // MARK: - Computed Properties

    var hasResults: Bool {
        smartCareResult != nil
    }

    // MARK: - Dependencies

    private let coordinator = CleanupCoordinator.shared
    private let xpcClient = XPCClient.shared
    private let defaults = UserDefaults.standard
    private let firstRunKey = "SmartCareFirstRunCompleted"

    // MARK: - Initialization

    init() {
        checkFirstRun()
    }

    // MARK: - Onboarding

    private func checkFirstRun() {
        if !defaults.bool(forKey: firstRunKey) {
            showOnboarding = true
        }
    }

    func completeOnboarding() {
        defaults.set(true, forKey: firstRunKey)
        showOnboarding = false
    }

    // MARK: - Smart Care Execution

    func runSmartCare() async {
        guard !isRunning else { return }

        isRunning = true
        progress = 0.0
        smartCareResult = nil
        error = nil

        var cleanupResult: CleanupResult?
        var memoryResult: MemoryOptimizationResult?
        var securityThreats: [SecurityThreat]?
        var errors: [String] = []

        do {
            // Step 1: System Cleanup (33%)
            currentTask = "Cleaning system files..."
            currentDetail = "Scanning for cleanable files"

            coordinator.selectAllCategories()
            await coordinator.scan()
            progress = 0.15

            if !coordinator.selectedItems.isEmpty {
                currentDetail = "Removing \(coordinator.selectedItems.count) items"
                cleanupResult = await coordinator.cleanup(useQuarantine: true)

                if !cleanupResult!.errors.isEmpty {
                    errors.append(contentsOf: cleanupResult!.errors)
                }
            } else {
                cleanupResult = CleanupResult(deletedCount: 0, freedSpace: 0, errors: [])
            }

            progress = 0.33
            try await Task.sleep(for: .milliseconds(300))

            // Step 2: Memory Optimization (66%)
            currentTask = "Optimizing memory..."
            currentDetail = "Freeing inactive memory"

            do {
                memoryResult = try await xpcClient.optimizeMemory()
            } catch {
                errors.append("Memory optimization: \(error.localizedDescription)")
                // Continue even if memory optimization fails
            }

            progress = 0.66
            try await Task.sleep(for: .milliseconds(300))

            // Step 3: Security Check (100%)
            currentTask = "Checking for threats..."
            currentDetail = "Scanning for malware and adware"

            do {
                let threats = try await xpcClient.scanForMalware()

                // Auto-remove low-risk threats, flag others for user review
                var removedThreats: [SecurityThreat] = []
                var flaggedThreats: [SecurityThreat] = []

                for threat in threats {
                    if threat.severity == .low {
                        do {
                            try await xpcClient.removeThreat(threat)
                            removedThreats.append(threat)
                        } catch {
                            errors.append("Failed to remove \(threat.name): \(error.localizedDescription)")
                            flaggedThreats.append(threat)
                        }
                    } else {
                        flaggedThreats.append(threat)
                    }
                }

                // Only show threats that weren't auto-removed
                securityThreats = flaggedThreats

                if !removedThreats.isEmpty {
                    currentDetail = "Removed \(removedThreats.count) low-risk threat(s)"
                }

            } catch {
                errors.append("Security scan: \(error.localizedDescription)")
            }

            progress = 1.0

            // Aggregate results
            smartCareResult = SmartCareResult(
                cleanup: cleanupResult,
                memory: memoryResult,
                securityThreats: securityThreats,
                errors: errors
            )

            lastRunDate = Date()

        } catch {
            self.error = error.localizedDescription
        }

        // Small delay before showing results
        try? await Task.sleep(for: .milliseconds(500))

        isRunning = false
    }

    // MARK: - Actions

    func reset() {
        smartCareResult = nil
        progress = 0.0
        currentTask = ""
        currentDetail = ""
    }

    // MARK: - Formatters

    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
