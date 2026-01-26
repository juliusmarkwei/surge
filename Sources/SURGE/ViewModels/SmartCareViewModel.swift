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
    @Published var cleanupResult: CleanupResult?
    @Published var lastRunDate: Date?
    @Published var error: String?

    // MARK: - Computed Properties

    var hasResults: Bool {
        cleanupResult != nil
    }

    // MARK: - Dependencies

    private let coordinator = CleanupCoordinator.shared
    private let xpcClient = XPCClient.shared

    // MARK: - Smart Care Execution

    func runSmartCare() async {
        guard !isRunning else { return }

        isRunning = true
        progress = 0.0
        cleanupResult = nil
        error = nil

        do {
            // Step 1: Scan for cleanable files (40% of progress)
            currentTask = "Scanning system..."
            currentDetail = "Finding cleanable files"

            coordinator.selectAllCategories()
            await coordinator.scan()

            progress = 0.4

            // Small delay for visual feedback
            try await Task.sleep(for: .milliseconds(500))

            // Step 2: Cleanup (60% of progress)
            if !coordinator.selectedItems.isEmpty {
                currentTask = "Cleaning up..."
                currentDetail = "Removing \(coordinator.selectedItems.count) items"

                let result = await coordinator.cleanup(useQuarantine: true)
                cleanupResult = result

                progress = 1.0
            } else {
                currentTask = "No cleanup needed"
                currentDetail = "Your system is already clean"

                cleanupResult = CleanupResult(
                    deletedCount: 0,
                    freedSpace: 0,
                    errors: []
                )

                progress = 1.0
            }

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
        cleanupResult = nil
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
