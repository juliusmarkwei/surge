//
//  CleanupCoordinator.swift
//  SURGE
//
//  Coordinates cleanup operations between UI and privileged helper.
//

import Foundation
import Combine
import Shared

@MainActor
class CleanupCoordinator: ObservableObject {

    static let shared = CleanupCoordinator()

    // MARK: - Published State

    @Published var isScanning: Bool = false
    @Published var isDeleting: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var deleteProgress: Double = 0.0
    @Published var cleanableItems: [CleanableItem] = []
    @Published var selectedCategories: Set<CleanupCategory> = Set(CleanupCategory.allCases)
    @Published var lastScanDate: Date?
    @Published var error: String?

    // MARK: - Computed Properties

    var selectedItems: [CleanableItem] {
        cleanableItems.filter { selectedCategories.contains($0.category) }
    }

    var totalSize: UInt64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var itemsByCategory: [CleanupCategory: [CleanableItem]] {
        Dictionary(grouping: cleanableItems, by: { $0.category })
    }

    // MARK: - Private Properties

    private let xpcClient = XPCClient.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Scanning

    func scan() async {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0.0
        cleanableItems = []
        error = nil

        do {
            let categoriesToScan = Array(selectedCategories)
            let totalCategories = Double(categoriesToScan.count)

            for (index, category) in categoriesToScan.enumerated() {
                // Scan each category
                let items = try await xpcClient.scanCleanableFiles(categories: [category])
                cleanableItems.append(contentsOf: items)

                // Update progress
                scanProgress = Double(index + 1) / totalCategories
            }

            lastScanDate = Date()

        } catch {
            self.error = "Scan failed: \(error.localizedDescription)"
        }

        isScanning = false
        scanProgress = 1.0
    }

    // MARK: - Cleanup

    func cleanup(useQuarantine: Bool = true) async -> CleanupResult? {
        guard !isDeleting else { return nil }
        guard !selectedItems.isEmpty else { return nil }

        isDeleting = true
        deleteProgress = 0.0
        error = nil

        let paths = selectedItems.map { $0.path }
        var result: CleanupResult?

        do {
            // Delete files
            result = try await xpcClient.deleteFiles(paths: paths, useQuarantine: useQuarantine)

            // Remove deleted items from list
            if let deletedCount = result?.deletedCount {
                cleanableItems.removeAll { item in
                    paths.contains(item.path)
                }
            }

            deleteProgress = 1.0

        } catch {
            self.error = "Cleanup failed: \(error.localizedDescription)"
        }

        isDeleting = false

        return result
    }

    // MARK: - Category Management

    func toggleCategory(_ category: CleanupCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func selectAllCategories() {
        selectedCategories = Set(CleanupCategory.allCases)
    }

    func deselectAllCategories() {
        selectedCategories.removeAll()
    }

    // MARK: - Utilities

    func reset() {
        cleanableItems = []
        selectedCategories = Set(CleanupCategory.allCases)
        lastScanDate = nil
        error = nil
    }

    func estimatedCleanupTime() -> TimeInterval {
        // Rough estimate: 100MB per second
        let seconds = Double(totalSize) / (100 * 1024 * 1024)
        return max(1.0, seconds)
    }
}
