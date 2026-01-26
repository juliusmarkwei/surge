//
//  SmartCareView.swift
//  SURGE
//
//  One-click system optimization view.
//

import SwiftUI
import Shared

struct SmartCareView: View {

    @StateObject private var viewModel = SmartCareViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main content
            if viewModel.isRunning {
                runningView
            } else if viewModel.hasResults {
                resultsView
            } else {
                readyView
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Care")
                    .font(.title)
                    .fontWeight(.bold)

                Text("One-click system optimization")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let lastRun = viewModel.lastRunDate {
                Text("Last run: \(viewModel.formatDate(lastRun))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Ready State

    private var readyView: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "wand.and.stars")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            VStack(spacing: 12) {
                Text("Ready to Optimize")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Smart Care will scan your system and safely clean up junk files to free up disk space.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 500)
            }

            // Features
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "folder.fill",
                    title: "System & User Caches",
                    description: "Remove temporary cache files"
                )

                FeatureRow(
                    icon: "doc.text.fill",
                    title: "Log Files",
                    description: "Clean up old log files"
                )

                FeatureRow(
                    icon: "trash.fill",
                    title: "Trash",
                    description: "Empty trash safely"
                )

                FeatureRow(
                    icon: "hammer.fill",
                    title: "Developer Junk",
                    description: "Remove build caches and package files"
                )
            }
            .frame(maxWidth: 400)

            // Action button
            Button {
                Task {
                    await viewModel.runSmartCare()
                }
            } label: {
                Label("Run Smart Care", systemImage: "wand.and.stars")
                    .font(.headline)
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Running State

    private var runningView: some View {
        VStack(spacing: 40) {
            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: viewModel.progress)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 12) {
                Text(viewModel.currentTask)
                    .font(.title2)
                    .fontWeight(.medium)

                ProgressView(value: viewModel.progress) {
                    Text("Progress")
                } currentValueLabel: {
                    Text("\(Int(viewModel.progress * 100))%")
                }
                .frame(width: 300)

                if !viewModel.currentDetail.isEmpty {
                    Text(viewModel.currentDetail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 32) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("Optimization Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your Mac has been optimized")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Results
            if let result = viewModel.cleanupResult {
                HStack(spacing: 32) {
                    ResultCard(
                        icon: "trash.fill",
                        value: "\(result.deletedCount)",
                        label: "Files Cleaned",
                        color: .orange
                    )

                    ResultCard(
                        icon: "internaldrive.fill",
                        value: viewModel.formatBytes(result.freedSpace),
                        label: "Space Freed",
                        color: .blue
                    )
                }
            }

            // System stats
            if let stats = appState.systemStats {
                VStack(spacing: 16) {
                    Text("Current System Status")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 24) {
                        SystemStatMini(
                            icon: "cpu",
                            label: "CPU",
                            value: String(format: "%.0f%%", stats.cpuUsage),
                            color: colorForPercentage(stats.cpuUsage)
                        )

                        SystemStatMini(
                            icon: "memorychip",
                            label: "Memory",
                            value: String(format: "%.0f%%", Double(stats.memoryUsed) / Double(stats.memoryTotal) * 100),
                            color: colorForPercentage(Double(stats.memoryUsed) / Double(stats.memoryTotal) * 100)
                        )

                        SystemStatMini(
                            icon: "internaldrive",
                            label: "Disk",
                            value: String(format: "%.0f%%", Double(stats.diskUsed) / Double(stats.diskTotal) * 100),
                            color: colorForPercentage(Double(stats.diskUsed) / Double(stats.diskTotal) * 100)
                        )
                    }
                }
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("Run Again") {
                    Task {
                        await viewModel.runSmartCare()
                    }
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Result Card

struct ResultCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)

            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 150, height: 150)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - System Stat Mini

struct SystemStatMini: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 80)
    }
}

// MARK: - Preview

#Preview {
    SmartCareView()
        .environmentObject(AppState.shared)
        .frame(width: 800, height: 600)
}
