//
//  PerformanceMonitorView.swift
//  SURGE
//
//  Real-time system performance monitoring with history graphs
//

import SwiftUI
import Shared
import Charts

struct PerformanceMonitorView: View {

    @StateObject private var viewModel = PerformanceMonitorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Quick stats cards
                    statsCardsView

                    // CPU Graph
                    cpuGraphCard

                    // Memory Graph
                    memoryGraphCard

                    // Per-Core CPU
                    perCoreView

                    // Actions
                    actionsView
                }
                .padding()
            }
        }
        .task {
            await viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Monitor")
                    .font(.headline)

                Text("Real-time system metrics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Monitoring indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(viewModel.isMonitoring ? "Live" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Stats Cards

    private var statsCardsView: some View {
        HStack(spacing: 16) {
            // CPU Card
            StatCard(
                title: "CPU Usage",
                value: String(format: "%.1f%%", viewModel.currentCPU),
                icon: "cpu",
                color: cpuColor(viewModel.currentCPU)
            )

            // Memory Card
            StatCard(
                title: "Memory Pressure",
                value: String(format: "%.1f%%", viewModel.currentMemoryPressure * 100),
                icon: "memorychip",
                color: memoryColor(viewModel.currentMemoryPressure)
            )

            // Memory Used Card
            StatCard(
                title: "Memory Used",
                value: formatBytes(viewModel.currentMemoryUsed),
                subtitle: "of \(formatBytes(viewModel.totalMemory))",
                icon: "square.stack.3d.up",
                color: .blue
            )
        }
    }

    // MARK: - CPU Graph

    private var cpuGraphCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("CPU Usage History", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)

                    Spacer()

                    Text("\(viewModel.historyPoints.count) samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if viewModel.historyPoints.isEmpty {
                    Text("Collecting data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(viewModel.historyPoints) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("CPU", point.cpuUsage)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("CPU", point.cpuUsage)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)%")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .frame(height: 150)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Memory Graph

    private var memoryGraphCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Memory Usage History", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Used")
                            .font(.caption2)

                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Pressure")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                if viewModel.historyPoints.isEmpty {
                    Text("Collecting data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(viewModel.historyPoints) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Used", Double(point.memoryUsed) / Double(viewModel.totalMemory) * 100)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Pressure", point.memoryPressure * 100)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)%")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .frame(height: 150)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Per-Core CPU

    private var perCoreView: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("CPU Cores", systemImage: "cpu.fill")
                    .font(.headline)

                if let perCoreUsage = viewModel.perCoreUsage {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120), spacing: 12)
                    ], spacing: 12) {
                        ForEach(Array(perCoreUsage.enumerated()), id: \.offset) { index, usage in
                            CoreUsageView(coreNumber: index, usage: usage)
                        }
                    }
                } else {
                    Text("Loading core data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private var actionsView: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack {
                    Label("Quick Actions", systemImage: "bolt.fill")
                        .font(.headline)

                    Spacer()
                }

                // Optimize Memory Button
                Button {
                    Task {
                        await viewModel.optimizeMemory()
                    }
                } label: {
                    HStack {
                        Image(systemName: "memorychip.fill")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Optimize Memory")
                                .fontWeight(.medium)
                            Text("Clear inactive memory and reduce pressure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        if viewModel.isOptimizing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isOptimizing)

                // Last optimization result
                if let result = viewModel.lastOptimizationResult {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        Text("Freed \(formatBytes(result.freedMemory)) • Pressure: \(String(format: "%.1f%%", result.beforePressure * 100)) → \(String(format: "%.1f%%", result.afterPressure * 100))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func cpuColor(_ usage: Double) -> Color {
        if usage < 50 { return .green }
        if usage < 75 { return .orange }
        return .red
    }

    private func memoryColor(_ pressure: Double) -> Color {
        if pressure < 0.5 { return .green }
        if pressure < 0.75 { return .orange }
        return .red
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .imageScale(.large)

                    Spacer()
                }

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Core Usage View

struct CoreUsageView: View {
    let coreNumber: Int
    let usage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Core \(coreNumber)")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(String(format: "%.1f%%", usage))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(usageColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(usageColor.gradient)
                        .frame(width: geometry.size.width * CGFloat(usage / 100))
                }
                .cornerRadius(4)
            }
            .frame(height: 6)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private var usageColor: Color {
        if usage < 50 { return .green }
        if usage < 75 { return .orange }
        return .red
    }
}

// MARK: - View Model

@MainActor
class PerformanceMonitorViewModel: ObservableObject {

    @Published var isMonitoring: Bool = false
    @Published var isOptimizing: Bool = false

    @Published var currentCPU: Double = 0
    @Published var currentMemoryUsed: UInt64 = 0
    @Published var currentMemoryPressure: Double = 0
    @Published var totalMemory: UInt64 = 0
    @Published var perCoreUsage: [Double]?

    @Published var historyPoints: [PerformanceDataPoint] = []
    @Published var lastOptimizationResult: MemoryOptimizationResult?

    private var monitoringTask: Task<Void, Never>?
    private let maxHistoryPoints = 60 // 3 minutes at 3-second intervals

    func startMonitoring() async {
        guard !isMonitoring else { return }

        isMonitoring = true

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await updateStats()

                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func updateStats() async {
        do {
            // Get CPU info
            let cpuInfo = try await XPCClient.shared.getCPUInfo()
            currentCPU = cpuInfo.averageUsage
            perCoreUsage = cpuInfo.perCoreUsage

            // Get memory info
            let memInfo = try await XPCClient.shared.getMemoryInfo()
            currentMemoryUsed = memInfo.usedRAM
            currentMemoryPressure = memInfo.memoryPressure
            totalMemory = memInfo.totalRAM

            // Add to history
            let point = PerformanceDataPoint(
                timestamp: Date(),
                cpuUsage: cpuInfo.averageUsage,
                memoryUsed: memInfo.usedRAM,
                memoryPressure: memInfo.memoryPressure
            )

            historyPoints.append(point)

            // Limit history size
            if historyPoints.count > maxHistoryPoints {
                historyPoints.removeFirst()
            }

        } catch {
            print("Performance monitoring error: \(error)")
        }
    }

    func optimizeMemory() async {
        guard !isOptimizing else { return }

        isOptimizing = true

        do {
            let result = try await XPCClient.shared.optimizeMemory()
            lastOptimizationResult = result

            // Update current stats
            await updateStats()

        } catch {
            print("Memory optimization error: \(error)")
        }

        isOptimizing = false
    }
}

// MARK: - Performance Data Point

struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsed: UInt64
    let memoryPressure: Double
}
