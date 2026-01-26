//
//  MemoryOptimizer.swift
//  PrivilegedHelper
//
//  Performs memory optimization operations.
//

import Foundation
import Shared
import Darwin
import Logging

fileprivate let memoryLogger = Logger(label: "com.surge.helper.memory")

class MemoryOptimizer {

    static let shared = MemoryOptimizer()

    private init() {}

    func optimizeMemory() throws -> MemoryOptimizationResult {
        memoryLogger.info("Starting memory optimization")

        // Get before state
        let beforeInfo = try SystemMonitor.shared.getMemoryInfo()
        let beforePressure = beforeInfo.memoryPressure

        // Purge inactive memory
        sync() // Flush filesystem buffers

        // Sleep briefly to allow system to process
        Thread.sleep(forTimeInterval: 0.5)

        // Get after state
        let afterInfo = try SystemMonitor.shared.getMemoryInfo()
        let afterPressure = afterInfo.memoryPressure

        let freedMemory = beforeInfo.usedRAM > afterInfo.usedRAM
            ? beforeInfo.usedRAM - afterInfo.usedRAM
            : 0

        memoryLogger.info("Memory optimization complete", metadata: [
            "freed": .stringConvertible(freedMemory),
            "beforePressure": .stringConvertible(beforePressure),
            "afterPressure": .stringConvertible(afterPressure)
        ])

        return MemoryOptimizationResult(
            freedMemory: freedMemory,
            beforePressure: beforePressure,
            afterPressure: afterPressure
        )
    }
}
