//
//  ByteCountFormatter+Extensions.swift
//  SURGE
//
//  Extensions for formatting byte counts.
//

import Foundation

extension ByteCountFormatter {

    static let fileSize: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter
    }()

    static let memorySize: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter
    }()
}

extension UInt64 {

    var formattedByteCount: String {
        ByteCountFormatter.fileSize.string(fromByteCount: Int64(self))
    }

    var formattedMemorySize: String {
        ByteCountFormatter.memorySize.string(fromByteCount: Int64(self))
    }
}
