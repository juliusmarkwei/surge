//
//  TreeMapLayout.swift
//  SURGE
//
//  Squarified TreeMap layout algorithm for disk space visualization
//

import Foundation
import Shared

/// TreeMap layout algorithm (Squarified)
/// Based on: "Squarified Treemaps" by Mark Bruls, Kees Huizing, Jarke J. van Wijk
struct TreeMapLayout {

    /// Layout items in a given rectangle
    static func layout(item: TreeMapItem, in rect: CGRect, minArea: Double = 4.0) -> [TreeMapRect] {
        var rectangles: [TreeMapRect] = []

        guard let children = item.children, !children.isEmpty else {
            // Leaf node
            return [TreeMapRect(
                item: item,
                x: rect.origin.x,
                y: rect.origin.y,
                width: rect.width,
                height: rect.height
            )]
        }

        // Sort children by size (descending)
        let sortedChildren = children.sorted { $0.size > $1.size }

        // Calculate total size
        let totalSize = Double(children.reduce(0) { $0 + $1.size })
        guard totalSize > 0 else { return [] }

        // Perform squarified layout
        var remaining = sortedChildren
        var currentRect = rect

        while !remaining.isEmpty {
            let row = selectRow(&remaining, totalSize: totalSize, in: currentRect)

            if row.isEmpty { break }

            let (layoutRects, newRect) = layoutRow(row, totalSize: totalSize, in: currentRect)

            // Only add rectangles that are visible (larger than minArea)
            for layoutRect in layoutRects where layoutRect.area >= minArea {
                rectangles.append(layoutRect)
            }

            currentRect = newRect
        }

        return rectangles
    }

    /// Select items for current row to minimize aspect ratio
    private static func selectRow(_ items: inout [TreeMapItem], totalSize: Double, in rect: CGRect) -> [TreeMapItem] {
        guard !items.isEmpty else { return [] }

        var row: [TreeMapItem] = [items.removeFirst()]
        var bestRatio = Double.infinity

        while !items.isEmpty {
            let candidate = row + [items.first!]
            let ratio = worstAspectRatio(candidate, totalSize: totalSize, in: rect)

            if ratio < bestRatio {
                bestRatio = ratio
                row.append(items.removeFirst())
            } else {
                // Adding more items would make aspect ratio worse
                break
            }
        }

        return row
    }

    /// Calculate worst aspect ratio for a row of items
    private static func worstAspectRatio(_ items: [TreeMapItem], totalSize: Double, in rect: CGRect) -> Double {
        guard !items.isEmpty else { return Double.infinity }

        let rowSize = Double(items.reduce(0) { $0 + $1.size })
        let rowRatio = rowSize / totalSize

        let shortSide = min(rect.width, rect.height)
        let longSide = max(rect.width, rect.height)

        let minArea = Double(items.map { $0.size }.min() ?? 0) / totalSize * rect.width * rect.height
        let maxArea = Double(items.map { $0.size }.max() ?? 0) / totalSize * rect.width * rect.height

        let ratio1 = (longSide * longSide * rowRatio) / (shortSide * shortSide * minArea / (rect.width * rect.height))
        let ratio2 = (shortSide * shortSide * maxArea / (rect.width * rect.height)) / (longSide * longSide * rowRatio)

        return max(ratio1, ratio2)
    }

    /// Layout a row of items
    private static func layoutRow(_ items: [TreeMapItem], totalSize: Double, in rect: CGRect) -> ([TreeMapRect], CGRect) {
        guard !items.isEmpty else { return ([], rect) }

        let rowSize = Double(items.reduce(0) { $0 + $1.size })
        let rowRatio = rowSize / totalSize

        // Determine if we're laying out horizontally or vertically
        let horizontal = rect.width >= rect.height
        let shortSide = min(rect.width, rect.height)
        let longSide = max(rect.width, rect.height)

        let rowLength = longSide
        let rowWidth = shortSide * rowRatio

        var rectangles: [TreeMapRect] = []
        var offset: Double = 0

        for item in items {
            let itemRatio = Double(item.size) / rowSize
            let itemLength = rowLength * itemRatio

            let layoutRect: TreeMapRect
            if horizontal {
                layoutRect = TreeMapRect(
                    item: item,
                    x: rect.origin.x + offset,
                    y: rect.origin.y,
                    width: itemLength,
                    height: rowWidth
                )
            } else {
                layoutRect = TreeMapRect(
                    item: item,
                    x: rect.origin.x,
                    y: rect.origin.y + offset,
                    width: rowWidth,
                    height: itemLength
                )
            }

            rectangles.append(layoutRect)
            offset += itemLength
        }

        // Calculate remaining rectangle
        let remainingRect: CGRect
        if horizontal {
            remainingRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y + rowWidth,
                width: rect.width,
                height: rect.height - rowWidth
            )
        } else {
            remainingRect = CGRect(
                x: rect.origin.x + rowWidth,
                y: rect.origin.y,
                width: rect.width - rowWidth,
                height: rect.height
            )
        }

        return (rectangles, remainingRect)
    }
}

// MARK: - CGRect Extension

extension CGRect {
    var area: Double {
        width * height
    }
}
