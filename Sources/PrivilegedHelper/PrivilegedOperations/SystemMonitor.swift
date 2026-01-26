//
//  SystemMonitor.swift
//  PrivilegedHelper
//
//  Monitors system resources (CPU, memory, disk).
//

import Foundation
import Shared
import Darwin
import Logging

fileprivate let monitorLogger = Logger(label: "com.surge.helper.monitor")

class SystemMonitor {

    static let shared = SystemMonitor()

    private init() {}

    // MARK: - System Stats

    func getSystemStats() throws -> SystemStats {
        let cpuUsage = try getCPUUsagePercentage()
        let (memoryUsed, memoryTotal) = try getMemoryUsage()
        let (diskUsed, diskTotal) = try getDiskUsage()

        return SystemStats(
            cpuUsage: cpuUsage,
            memoryUsed: memoryUsed,
            memoryTotal: memoryTotal,
            diskUsed: diskUsed,
            diskTotal: diskTotal,
            timestamp: Date()
        )
    }

    // MARK: - CPU Information

    func getCPUInfo() throws -> CPUInfo {
        var processorInfo: processor_info_array_t!
        var numProcessorInfo: mach_msg_type_number_t = 0
        var numProcessors: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &processorInfo,
            &numProcessorInfo
        )

        guard result == KERN_SUCCESS else {
            throw NSError(domain: "SystemMonitor", code: Int(result), userInfo: [
                NSLocalizedDescriptionKey: "Failed to get CPU info"
            ])
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: processorInfo),
                vm_size_t(numProcessorInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        var perCoreUsage: [Double] = []
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0

        for i in 0..<Int(numProcessors) {
            let cpuLoadInfo = processorInfo.advanced(by: Int(i) * Int(CPU_STATE_MAX))
                .withMemoryRebound(to: integer_t.self, capacity: Int(CPU_STATE_MAX)) { $0 }

            let user = UInt64(cpuLoadInfo[Int(CPU_STATE_USER)])
            let system = UInt64(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            let nice = UInt64(cpuLoadInfo[Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice

            let usage = total > 0 ? Double(user + system) / Double(total) * 100.0 : 0.0
            perCoreUsage.append(usage)

            totalUser += user
            totalSystem += system
            totalIdle += idle
        }

        let totalTicks = totalUser + totalSystem + totalIdle
        let averageUsage = totalTicks > 0 ? Double(totalUser + totalSystem) / Double(totalTicks) * 100.0 : 0.0
        let userUsage = totalTicks > 0 ? Double(totalUser) / Double(totalTicks) * 100.0 : 0.0
        let systemUsage = totalTicks > 0 ? Double(totalSystem) / Double(totalTicks) * 100.0 : 0.0

        return CPUInfo(
            coreCount: Int(numProcessors),
            perCoreUsage: perCoreUsage,
            averageUsage: averageUsage,
            systemUsage: systemUsage,
            userUsage: userUsage
        )
    }

    private func getCPUUsagePercentage() throws -> Double {
        let info = try getCPUInfo()
        return info.averageUsage
    }

    // MARK: - Memory Information

    func getMemoryInfo() throws -> MemoryInfo {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    $0,
                    &size
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw NSError(domain: "SystemMonitor", code: Int(result), userInfo: [
                NSLocalizedDescriptionKey: "Failed to get memory info"
            ])
        }

        let pageSize = UInt64(vm_kernel_page_size)

        let activeRAM = UInt64(vmStats.active_count) * pageSize
        let inactiveRAM = UInt64(vmStats.inactive_count) * pageSize
        let wiredRAM = UInt64(vmStats.wire_count) * pageSize
        let compressedRAM = UInt64(vmStats.compressor_page_count) * pageSize

        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let usedRAM = activeRAM + wiredRAM + compressedRAM

        // Calculate memory pressure (0.0 - 1.0)
        let memoryPressure = min(Double(usedRAM) / Double(totalRAM), 1.0)

        return MemoryInfo(
            totalRAM: totalRAM,
            usedRAM: usedRAM,
            activeRAM: activeRAM,
            inactiveRAM: inactiveRAM,
            wiredRAM: wiredRAM,
            compressedRAM: compressedRAM,
            memoryPressure: memoryPressure
        )
    }

    private func getMemoryUsage() throws -> (used: UInt64, total: UInt64) {
        let info = try getMemoryInfo()
        return (info.usedRAM, info.totalRAM)
    }

    // MARK: - Disk Usage

    private func getDiskUsage() throws -> (used: UInt64, total: UInt64) {
        let fileManager = FileManager.default
        let rootPath = "/"

        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: rootPath) else {
            throw NSError(domain: "SystemMonitor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get disk info"
            ])
        }

        let total = (attributes[.systemSize] as? NSNumber)?.uint64Value ?? 0
        let free = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        let used = total - free

        return (used, total)
    }
}
