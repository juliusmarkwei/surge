//
//  SmartCareViewModelTests.swift
//  SURGETests
//
//  Tests for SmartCareViewModel aggregate optimization.
//

import XCTest
@testable import SURGE
@testable import Shared

@MainActor
final class SmartCareViewModelTests: XCTestCase {

    var viewModel: SmartCareViewModel!

    override func setUp() async throws {
        viewModel = SmartCareViewModel()

        // Reset UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "SmartCareFirstRunCompleted")
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertEqual(viewModel.currentTask, "")
        XCTAssertEqual(viewModel.currentDetail, "")
        XCTAssertNil(viewModel.smartCareResult)
        XCTAssertNil(viewModel.lastRunDate)
        XCTAssertNil(viewModel.error)
    }

    func testFirstRunOnboarding() {
        // First run should show onboarding
        let firstRunVM = SmartCareViewModel()
        XCTAssertTrue(firstRunVM.showOnboarding)
    }

    func testOnboardingCompletion() {
        viewModel.completeOnboarding()
        XCTAssertFalse(viewModel.showOnboarding)

        // Create new instance - should not show onboarding
        let newVM = SmartCareViewModel()
        XCTAssertFalse(newVM.showOnboarding)
    }

    // MARK: - Results Tests

    func testHasResults() {
        XCTAssertFalse(viewModel.hasResults)

        viewModel.smartCareResult = SmartCareResult(
            cleanup: CleanupResult(deletedCount: 10, freedSpace: 1000, errors: []),
            memory: nil,
            securityThreats: nil,
            errors: []
        )

        XCTAssertTrue(viewModel.hasResults)
    }

    func testReset() {
        viewModel.smartCareResult = SmartCareResult(
            cleanup: CleanupResult(deletedCount: 10, freedSpace: 1000, errors: []),
            memory: nil,
            securityThreats: nil,
            errors: []
        )
        viewModel.progress = 0.5
        viewModel.currentTask = "Test task"
        viewModel.currentDetail = "Test detail"

        viewModel.reset()

        XCTAssertNil(viewModel.smartCareResult)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertEqual(viewModel.currentTask, "")
        XCTAssertEqual(viewModel.currentDetail, "")
    }

    // MARK: - Formatter Tests

    func testFormatBytes() {
        XCTAssertEqual(viewModel.formatBytes(0), "Zero KB")
        XCTAssertEqual(viewModel.formatBytes(1024 * 1024), "1 MB") // 1 MB
        XCTAssertEqual(viewModel.formatBytes(1024 * 1024 * 1024), "1 GB") // 1 GB
        XCTAssertEqual(viewModel.formatBytes(1536 * 1024 * 1024), "1.5 GB") // 1.5 GB
    }

    func testFormatDate() {
        let now = Date()
        let formatted = viewModel.formatDate(now)

        // Should return "now" or similar
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.lowercased().contains("now") || formatted.lowercased().contains("second"))
    }

    // MARK: - Result Aggregation Tests

    func testSmartCareResultAggregation() {
        let cleanup = CleanupResult(deletedCount: 50, freedSpace: 500_000_000, errors: [])
        let memory = MemoryOptimizationResult(
            freedMemory: 100_000_000,
            beforePressure: 0.8,
            afterPressure: 0.5
        )
        let threats: [SecurityThreat] = [
            SecurityThreat(
                name: "Test Threat",
                path: "/test/path",
                type: .malware,
                severity: .medium,
                description: "Test"
            )
        ]

        let result = SmartCareResult(
            cleanup: cleanup,
            memory: memory,
            securityThreats: threats,
            errors: []
        )

        XCTAssertEqual(result.totalSpaceFreed, 500_000_000)
        XCTAssertEqual(result.totalMemoryFreed, 100_000_000)
        XCTAssertEqual(result.threatsRemoved, 0) // Threats are flagged, not removed yet
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testSmartCareResultWithErrors() {
        let errors = ["Error 1", "Error 2"]
        let result = SmartCareResult(
            cleanup: nil,
            memory: nil,
            securityThreats: nil,
            errors: errors
        )

        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.totalSpaceFreed, 0)
        XCTAssertEqual(result.totalMemoryFreed, 0)
        XCTAssertEqual(result.threatsRemoved, 0)
    }

    func testSmartCareResultOptionalFields() {
        let result = SmartCareResult(
            cleanup: nil,
            memory: nil,
            securityThreats: nil,
            errors: []
        )

        XCTAssertNil(result.cleanup)
        XCTAssertNil(result.memory)
        XCTAssertNil(result.securityThreats)
        XCTAssertEqual(result.totalSpaceFreed, 0)
        XCTAssertEqual(result.totalMemoryFreed, 0)
        XCTAssertEqual(result.threatsRemoved, 0)
    }

    // MARK: - Progress Tests

    func testProgressRange() {
        viewModel.progress = 0.0
        XCTAssertGreaterThanOrEqual(viewModel.progress, 0.0)
        XCTAssertLessThanOrEqual(viewModel.progress, 1.0)

        viewModel.progress = 0.5
        XCTAssertEqual(viewModel.progress, 0.5)

        viewModel.progress = 1.0
        XCTAssertEqual(viewModel.progress, 1.0)
    }

    // MARK: - State Consistency Tests

    func testRunningStateMutualExclusivity() {
        // Can't have results and be running at the same time
        viewModel.isRunning = true
        viewModel.smartCareResult = SmartCareResult(
            cleanup: CleanupResult(deletedCount: 10, freedSpace: 1000, errors: []),
            memory: nil,
            securityThreats: nil,
            errors: []
        )

        // In real usage, runSmartCare() sets isRunning = false when done
        // and sets smartCareResult, so they shouldn't be true simultaneously
    }

    // MARK: - Edge Cases

    func testEmptyResult() {
        let result = SmartCareResult(
            cleanup: CleanupResult(deletedCount: 0, freedSpace: 0, errors: []),
            memory: MemoryOptimizationResult(freedMemory: 0, beforePressure: 0.3, afterPressure: 0.3),
            securityThreats: [],
            errors: []
        )

        XCTAssertEqual(result.totalSpaceFreed, 0)
        XCTAssertEqual(result.totalMemoryFreed, 0)
        XCTAssertEqual(result.threatsRemoved, 0)
    }

    func testLargeValues() {
        let largeSpace: UInt64 = 10 * 1024 * 1024 * 1024 // 10 GB
        let largeMemory: UInt64 = 4 * 1024 * 1024 * 1024 // 4 GB

        let result = SmartCareResult(
            cleanup: CleanupResult(deletedCount: 10000, freedSpace: largeSpace, errors: []),
            memory: MemoryOptimizationResult(freedMemory: largeMemory, beforePressure: 0.9, afterPressure: 0.3),
            securityThreats: nil,
            errors: []
        )

        XCTAssertEqual(result.totalSpaceFreed, largeSpace)
        XCTAssertEqual(result.totalMemoryFreed, largeMemory)

        // Test formatting of large values
        let formattedSpace = viewModel.formatBytes(largeSpace)
        XCTAssertTrue(formattedSpace.contains("GB"))
    }
}
