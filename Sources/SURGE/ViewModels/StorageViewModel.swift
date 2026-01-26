//
//  StorageViewModel.swift
//  SURGE
//
//  ViewModel for Storage Management view.
//

import Foundation
import SwiftUI
import Shared

@MainActor
class StorageViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentTab: StorageTab = .cleanup
    @Published var showingCleanupPreview: Bool = false
    @Published var showingCleanupResult: Bool = false
    @Published var lastCleanupResult: CleanupResult?

    enum StorageTab {
        case cleanup
        case spaceLens
        case duplicates
    }

    // MARK: - Dependencies

    let coordinator = CleanupCoordinator.shared

    // MARK: - Actions

    func performScan() async {
        await coordinator.scan()
    }

    func performCleanup(useQuarantine: Bool = true) async {
        let result = await coordinator.cleanup(useQuarantine: useQuarantine)
        lastCleanupResult = result
        showingCleanupResult = true
    }

    func previewCleanup() {
        showingCleanupPreview = true
    }

    // MARK: - Formatters

    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    func formatItemCount(_ count: Int) -> String {
        if count == 1 {
            return "1 item"
        } else {
            return "\(count) items"
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
