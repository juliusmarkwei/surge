//
//  MenuBarView.swift
//  SURGE
//
//  Menu bar dropdown view.
//

import SwiftUI
import Shared

struct MenuBarView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // System stats
            if let stats = appState.systemStats {
                systemStatsSection(stats)
            } else {
                loadingSection
            }

            Divider()

            // Actions
            actionsSection

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 280)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("SURGE")
                .font(.headline)

            if !appState.isHelperConnected {
                Label("Helper Not Connected", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 12)
    }

    private func systemStatsSection(_ stats: SystemStats) -> some View {
        VStack(spacing: 12) {
            // CPU
            StatRow(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.1f%%", stats.cpuUsage),
                color: colorForPercentage(stats.cpuUsage)
            )

            // Memory
            let memoryPercent = Double(stats.memoryUsed) / Double(stats.memoryTotal) * 100
            StatRow(
                icon: "memorychip",
                label: "Memory",
                value: String(format: "%.1f%%", memoryPercent),
                subtitle: "\(formatBytes(stats.memoryUsed)) / \(formatBytes(stats.memoryTotal))",
                color: colorForPercentage(memoryPercent)
            )

            // Disk
            let diskPercent = Double(stats.diskUsed) / Double(stats.diskTotal) * 100
            StatRow(
                icon: "internaldrive",
                label: "Disk",
                value: String(format: "%.1f%%", diskPercent),
                subtitle: "\(formatBytes(stats.diskUsed)) / \(formatBytes(stats.diskTotal))",
                color: colorForPercentage(diskPercent)
            )
        }
        .padding(.vertical, 12)
    }

    private var loadingSection: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("Loading stats...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button {
                appState.openMainWindow()
            } label: {
                Label("Open SURGE", systemImage: "app.dashed")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                // Open settings
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Button("Quit SURGE") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)

            if let updateTime = appState.systemStats?.timestamp {
                Text("Updated \(timeAgo(updateTime))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func colorForPercentage(_ percent: Double) -> Color {
        if percent < 60 {
            return .green
        } else if percent < 80 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else {
            return "\(seconds / 60)m ago"
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var subtitle: String?
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 16)
    }
}
