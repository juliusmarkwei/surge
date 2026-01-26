//
//  TreeMapModels.swift
//  Shared
//
//  Data models for TreeMap disk space visualization
//

import Foundation

/// Represents a file or directory in the tree map
public struct TreeMapItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let name: String
    public let size: UInt64
    public let isDirectory: Bool
    public let children: [TreeMapItem]?
    public let modificationDate: Date?

    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        size: UInt64,
        isDirectory: Bool,
        children: [TreeMapItem]? = nil,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.modificationDate = modificationDate
    }
}

/// Rectangle for TreeMap layout
public struct TreeMapRect: Identifiable {
    public let id: UUID
    public let item: TreeMapItem
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(item: TreeMapItem, x: Double, y: Double, width: Double, height: Double) {
        self.id = item.id
        self.item = item
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var area: Double {
        width * height
    }
}

/// Duplicate file group
public struct DuplicateGroup: Codable, Sendable, Identifiable {
    public let id: UUID
    public let hash: String
    public let files: [DuplicateFile]
    public let totalSize: UInt64
    public let fileCount: Int

    public init(hash: String, files: [DuplicateFile]) {
        self.id = UUID()
        self.hash = hash
        self.files = files
        self.totalSize = files.reduce(0) { $0 + $1.size }
        self.fileCount = files.count
    }

    public var wastedSpace: UInt64 {
        // All copies except one are wasted
        guard fileCount > 1 else { return 0 }
        return totalSize - (files.first?.size ?? 0)
    }
}

/// Individual duplicate file
public struct DuplicateFile: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let name: String
    public let size: UInt64
    public let modificationDate: Date

    public init(path: String, name: String, size: UInt64, modificationDate: Date) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
    }
}

/// Large file item
public struct LargeFileItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let name: String
    public let size: UInt64
    public let modificationDate: Date
    public let lastAccessDate: Date?

    public init(path: String, name: String, size: UInt64, modificationDate: Date, lastAccessDate: Date? = nil) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.lastAccessDate = lastAccessDate
    }

    public var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: modificationDate, to: Date()).day ?? 0
    }
}

/// Installed application info
public struct InstalledApp: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String
    public let path: String
    public let version: String?
    public let size: UInt64
    public let associatedFiles: [String]
    public let totalSize: UInt64

    public init(
        name: String,
        bundleIdentifier: String,
        path: String,
        version: String?,
        size: UInt64,
        associatedFiles: [String],
        totalSize: UInt64
    ) {
        self.id = UUID()
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.version = version
        self.size = size
        self.associatedFiles = associatedFiles
        self.totalSize = totalSize
    }
}
