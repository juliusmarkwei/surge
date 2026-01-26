//
//  TreeMapLayoutTests.swift
//  SURGETests
//
//  Tests for squarified TreeMap layout algorithm.
//

import XCTest
@testable import SURGE
@testable import Shared
import CoreGraphics

final class TreeMapLayoutTests: XCTestCase {

    // MARK: - Basic Layout Tests

    func testEmptyTreeMapReturnsEmptyArray() {
        let item = TreeMapItem(
            path: "/test",
            name: "test",
            size: 0,
            isDirectory: true,
            children: [],
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = TreeMapLayout.layout(item: item, in: rect)

        XCTAssertTrue(result.isEmpty)
    }

    func testSingleItemFillsEntireRect() {
        let item = TreeMapItem(
            path: "/test/file1",
            name: "file1",
            size: 1000,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 1000,
            isDirectory: true,
            children: [item],
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = TreeMapLayout.layout(item: parentItem, in: rect)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].width, 100, accuracy: 1.0)
        XCTAssertEqual(result[0].height, 100, accuracy: 1.0)
        XCTAssertEqual(result[0].item.name, "file1")
    }

    func testMultipleItemsAreDistributed() {
        let item1 = TreeMapItem(
            path: "/test/file1",
            name: "file1",
            size: 500,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let item2 = TreeMapItem(
            path: "/test/file2",
            name: "file2",
            size: 500,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 1000,
            isDirectory: true,
            children: [item1, item2],
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = TreeMapLayout.layout(item: parentItem, in: rect)

        XCTAssertEqual(result.count, 2)

        // Both items should have equal area (500 each out of 1000 total)
        let totalArea = rect.width * rect.height
        let expectedAreaPerItem = totalArea * 0.5

        for layoutRect in result {
            let area = layoutRect.area
            XCTAssertEqual(area, expectedAreaPerItem, accuracy: 10.0)
        }
    }

    func testProportionalSizes() {
        let item1 = TreeMapItem(
            path: "/test/large",
            name: "large",
            size: 800,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let item2 = TreeMapItem(
            path: "/test/small",
            name: "small",
            size: 200,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 1000,
            isDirectory: true,
            children: [item1, item2],
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = TreeMapLayout.layout(item: parentItem, in: rect)

        XCTAssertEqual(result.count, 2)

        let largeRect = result.first { $0.item.name == "large" }
        let smallRect = result.first { $0.item.name == "small" }

        XCTAssertNotNil(largeRect)
        XCTAssertNotNil(smallRect)

        let largeArea = largeRect!.area
        let smallArea = smallRect!.area

        // Large item should have ~4x the area of small item (800 vs 200)
        let areaRatio = largeArea / smallArea
        XCTAssertEqual(areaRatio, 4.0, accuracy: 0.5)
    }

    // MARK: - Squarified Algorithm Tests

    func testSquarifiedMinimizesAspectRatio() {
        // Create items with various sizes
        let items = [
            TreeMapItem(path: "/1", name: "1", size: 600, isDirectory: false, children: nil, modificationDate: nil),
            TreeMapItem(path: "/2", name: "2", size: 200, isDirectory: false, children: nil, modificationDate: nil),
            TreeMapItem(path: "/3", name: "3", size: 100, isDirectory: false, children: nil, modificationDate: nil),
            TreeMapItem(path: "/4", name: "4", size: 100, isDirectory: false, children: nil, modificationDate: nil),
        ]

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 1000,
            isDirectory: true,
            children: items,
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = TreeMapLayout.layout(item: parentItem, in: rect)

        XCTAssertEqual(result.count, 4)

        // Calculate average aspect ratio
        var totalAspectRatio: CGFloat = 0
        for layoutRect in result {
            let width = layoutRect.width
            let height = layoutRect.height
            let aspectRatio = max(width, height) / min(width, height)
            totalAspectRatio += aspectRatio
        }

        let averageAspectRatio = totalAspectRatio / CGFloat(result.count)

        // Squarified algorithm should keep aspect ratio closer to 1.0 (square)
        // Average should be less than 3.0 for well-distributed items
        XCTAssertLessThan(averageAspectRatio, 3.0)
    }

    // MARK: - MinArea Filtering Tests

    func testMinAreaFiltering() {
        let items = (1...100).map { i in
            TreeMapItem(
                path: "/test/\(i)",
                name: "file\(i)",
                size: UInt64(i * 10), // 10, 20, 30, ... 1000
                isDirectory: false,
                children: nil,
                modificationDate: nil
            )
        }

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: items.reduce(0) { $0 + $1.size },
            isDirectory: true,
            children: items,
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        // With minArea = 100, should filter out very small rectangles
        let resultWithFilter = TreeMapLayout.layout(item: parentItem, in: rect, minArea: 100.0)

        // Without filter, should include more rectangles
        let resultWithoutFilter = TreeMapLayout.layout(item: parentItem, in: rect, minArea: 0.1)

        XCTAssertLessThan(resultWithFilter.count, resultWithoutFilter.count)

        // All filtered rectangles should have area >= minArea
        for layoutRect in resultWithFilter {
            XCTAssertGreaterThanOrEqual(layoutRect.area, 100.0)
        }
    }

    // MARK: - Edge Cases

    func testZeroSizeItemsIgnored() {
        let item1 = TreeMapItem(
            path: "/test/file1",
            name: "file1",
            size: 1000,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let item2 = TreeMapItem(
            path: "/test/empty",
            name: "empty",
            size: 0,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 1000,
            isDirectory: true,
            children: [item1, item2],
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = TreeMapLayout.layout(item: parentItem, in: rect)

        // Should only layout non-zero size items
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].item.name, "file1")
    }

    func testVerySmallRectangle() {
        let item = TreeMapItem(
            path: "/test/file1",
            name: "file1",
            size: 1000,
            isDirectory: false,
            children: nil,
            modificationDate: nil
        )

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 1000,
            isDirectory: true,
            children: [item],
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let result = TreeMapLayout.layout(item: parentItem, in: rect, minArea: 0.1)

        // Even with tiny rect, should return result
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].width, 1.0, accuracy: 0.1)
        XCTAssertEqual(result[0].height, 1.0, accuracy: 0.1)
    }

    func testLargeNumberOfItems() {
        let items = (1...1000).map { i in
            TreeMapItem(
                path: "/test/\(i)",
                name: "file\(i)",
                size: 100,
                isDirectory: false,
                children: nil,
                modificationDate: nil
            )
        }

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: 100000,
            isDirectory: true,
            children: items,
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        // Should handle large number of items without crashing
        let result = TreeMapLayout.layout(item: parentItem, in: rect, minArea: 10.0)

        XCTAssertGreaterThan(result.count, 0)
        XCTAssertLessThanOrEqual(result.count, 1000)

        // Verify all rectangles are within bounds
        for layoutRect in result {
            XCTAssertGreaterThanOrEqual(layoutRect.x, 0)
            XCTAssertGreaterThanOrEqual(layoutRect.y, 0)
            XCTAssertLessThanOrEqual(layoutRect.x + layoutRect.width, 1000)
            XCTAssertLessThanOrEqual(layoutRect.y + layoutRect.height, 1000)
        }
    }

    // MARK: - Performance Tests

    func testLayoutPerformance() {
        let items = (1...10000).map { i in
            TreeMapItem(
                path: "/test/\(i)",
                name: "file\(i)",
                size: UInt64.random(in: 100...10000),
                isDirectory: false,
                children: nil,
                modificationDate: nil
            )
        }

        let parentItem = TreeMapItem(
            path: "/test",
            name: "test",
            size: items.reduce(0) { $0 + $1.size },
            isDirectory: true,
            children: items,
            modificationDate: nil
        )

        let rect = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        measure {
            _ = TreeMapLayout.layout(item: parentItem, in: rect, minArea: 25.0)
        }
    }
}
