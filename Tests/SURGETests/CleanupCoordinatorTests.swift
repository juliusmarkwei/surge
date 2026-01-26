//
//  CleanupCoordinatorTests.swift
//  SURGETests
//
//  Tests for CleanupCoordinator.
//

import XCTest
@testable import SURGE
@testable import Shared

final class CleanupCoordinatorTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let coordinator = CleanupCoordinator.shared

        XCTAssertFalse(coordinator.isScanning)
        XCTAssertFalse(coordinator.isDeleting)
        XCTAssertEqual(coordinator.scanProgress, 0.0)
        XCTAssertEqual(coordinator.deleteProgress, 0.0)
        XCTAssertTrue(coordinator.cleanableItems.isEmpty)
        XCTAssertEqual(coordinator.selectedCategories.count, CleanupCategory.allCases.count)
    }

    @MainActor
    func testCategorySelection() {
        let coordinator = CleanupCoordinator.shared

        // Initially all selected
        XCTAssertEqual(coordinator.selectedCategories.count, CleanupCategory.allCases.count)

        // Toggle off
        coordinator.toggleCategory(.systemCaches)
        XCTAssertFalse(coordinator.selectedCategories.contains(.systemCaches))

        // Toggle back on
        coordinator.toggleCategory(.systemCaches)
        XCTAssertTrue(coordinator.selectedCategories.contains(.systemCaches))
    }

    @MainActor
    func testSelectAllCategories() {
        let coordinator = CleanupCoordinator.shared

        coordinator.deselectAllCategories()
        XCTAssertTrue(coordinator.selectedCategories.isEmpty)

        coordinator.selectAllCategories()
        XCTAssertEqual(coordinator.selectedCategories.count, CleanupCategory.allCases.count)
    }

    @MainActor
    func testTotalSizeCalculation() {
        let coordinator = CleanupCoordinator.shared

        // Create mock items
        let item1 = CleanableItem(
            path: "/test/item1",
            size: 1000,
            category: .systemCaches,
            description: "Test item 1",
            lastModified: Date()
        )

        let item2 = CleanableItem(
            path: "/test/item2",
            size: 2000,
            category: .userCaches,
            description: "Test item 2",
            lastModified: Date()
        )

        coordinator.cleanableItems = [item1, item2]

        // With all categories selected
        XCTAssertEqual(coordinator.totalSize, 3000)

        // Deselect one category
        coordinator.toggleCategory(.systemCaches)
        XCTAssertEqual(coordinator.totalSize, 2000)
    }

    @MainActor
    func testItemsByCategory() {
        let coordinator = CleanupCoordinator.shared

        let item1 = CleanableItem(
            path: "/test/item1",
            size: 1000,
            category: .systemCaches,
            description: "Test item 1",
            lastModified: Date()
        )

        let item2 = CleanableItem(
            path: "/test/item2",
            size: 2000,
            category: .systemCaches,
            description: "Test item 2",
            lastModified: Date()
        )

        let item3 = CleanableItem(
            path: "/test/item3",
            size: 3000,
            category: .logs,
            description: "Test item 3",
            lastModified: Date()
        )

        coordinator.cleanableItems = [item1, item2, item3]

        let grouped = coordinator.itemsByCategory

        XCTAssertEqual(grouped[.systemCaches]?.count, 2)
        XCTAssertEqual(grouped[.logs]?.count, 1)
        XCTAssertNil(grouped[.trash])
    }

    @MainActor
    func testReset() {
        let coordinator = CleanupCoordinator.shared

        coordinator.cleanableItems = [
            CleanableItem(
                path: "/test",
                size: 1000,
                category: .systemCaches,
                description: "Test",
                lastModified: Date()
            )
        ]
        coordinator.lastScanDate = Date()
        coordinator.toggleCategory(.systemCaches)

        coordinator.reset()

        XCTAssertTrue(coordinator.cleanableItems.isEmpty)
        XCTAssertNil(coordinator.lastScanDate)
        XCTAssertEqual(coordinator.selectedCategories.count, CleanupCategory.allCases.count)
    }

    @MainActor
    func testEstimatedCleanupTime() {
        let coordinator = CleanupCoordinator.shared

        // Empty
        XCTAssertEqual(coordinator.estimatedCleanupTime(), 1.0) // Minimum 1 second

        // 200MB (should be ~2 seconds at 100MB/s)
        coordinator.cleanableItems = [
            CleanableItem(
                path: "/test",
                size: 200 * 1024 * 1024,
                category: .systemCaches,
                description: "Test",
                lastModified: Date()
            )
        ]

        let estimatedTime = coordinator.estimatedCleanupTime()
        XCTAssertGreaterThan(estimatedTime, 1.0)
        XCTAssertLessThan(estimatedTime, 5.0)
    }
}
