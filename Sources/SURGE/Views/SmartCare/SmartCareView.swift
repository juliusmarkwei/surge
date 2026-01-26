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
        ZStack {
            // Main content
            mainContent

            // Onboarding overlay
            if viewModel.showOnboarding {
                OnboardingView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Ready to Optimize")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Smart Care combines system cleanup, memory optimization, and security scanning into one powerful tool.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 500)
            }

            // Features
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "internaldrive.fill",
                    title: "System Cleanup",
                    description: "Remove caches, logs, and temporary files"
                )

                FeatureRow(
                    icon: "memorychip.fill",
                    title: "Memory Optimization",
                    description: "Free inactive memory and reduce pressure"
                )

                FeatureRow(
                    icon: "shield.checkered",
                    title: "Security Check",
                    description: "Scan for malware and adware"
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
            // Animated progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: viewModel.progress)

                VStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            VStack(spacing: 12) {
                Text(viewModel.currentTask)
                    .font(.title2)
                    .fontWeight(.medium)

                if !viewModel.currentDetail.isEmpty {
                    Text(viewModel.currentDetail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress steps
            VStack(spacing: 8) {
                ProgressStepRow(
                    title: "System Cleanup",
                    isComplete: viewModel.progress > 0.33,
                    isActive: viewModel.progress <= 0.33
                )
                ProgressStepRow(
                    title: "Memory Optimization",
                    isComplete: viewModel.progress > 0.66,
                    isActive: viewModel.progress > 0.33 && viewModel.progress <= 0.66
                )
                ProgressStepRow(
                    title: "Security Check",
                    isComplete: viewModel.progress >= 1.0,
                    isActive: viewModel.progress > 0.66 && viewModel.progress < 1.0
                )
            }
            .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                VStack(spacing: 12) {
                    Text("Optimization Complete!")
                        .font(.title)
                        .fontWeight(.bold)

                    if let result = viewModel.smartCareResult {
                        Text(summaryText(result))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 500)
                    }
                }

                // Results cards
                if let result = viewModel.smartCareResult {
                    HStack(spacing: 24) {
                        // Cleanup result
                        if let cleanup = result.cleanup, cleanup.deletedCount > 0 {
                            ResultCard(
                                icon: "internaldrive.fill",
                                value: viewModel.formatBytes(cleanup.freedSpace),
                                label: "\(cleanup.deletedCount) items cleaned",
                                color: .blue
                            )
                        }

                        // Memory result
                        if let memory = result.memory, memory.freedMemory > 0 {
                            ResultCard(
                                icon: "memorychip.fill",
                                value: viewModel.formatBytes(memory.freedMemory),
                                label: String(format: "%.0f%% pressure reduced",
                                             (memory.beforePressure - memory.afterPressure) * 100),
                                color: .purple
                            )
                        }
                    }

                    // Security alert card
                    if let threats = result.securityThreats, !threats.isEmpty {
                        SecurityAlertCard(threats: threats)
                            .frame(maxWidth: 500)
                    }

                    // Errors card
                    if !result.errors.isEmpty {
                        ErrorsCard(errors: result.errors)
                            .frame(maxWidth: 500)
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
            .frame(maxWidth: .infinity)
            .padding()
        }
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

    private func summaryText(_ result: SmartCareResult) -> String {
        var parts: [String] = []

        if result.totalSpaceFreed > 0 {
            parts.append("\(viewModel.formatBytes(result.totalSpaceFreed)) space freed")
        }

        if result.totalMemoryFreed > 0 {
            parts.append("\(viewModel.formatBytes(result.totalMemoryFreed)) memory optimized")
        }

        if result.threatsRemoved > 0 {
            parts.append("\(result.threatsRemoved) low-risk threat(s) removed")
        }

        if let threats = result.securityThreats, !threats.isEmpty {
            parts.append("\(threats.count) threat(s) flagged for review")
        }

        if parts.isEmpty {
            return "Your Mac is already optimized"
        }

        return parts.joined(separator: " • ")
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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

// MARK: - Progress Step Row

struct ProgressStepRow: View {
    let title: String
    let isComplete: Bool
    let isActive: Bool

    var body: some View {
        HStack {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isActive {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }

            Text(title)
                .font(.body)
                .foregroundColor(isActive ? .primary : .secondary)

            Spacer()
        }
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
                .multilineTextAlignment(.center)
        }
        .frame(width: 180, height: 160)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Security Alert Card

struct SecurityAlertCard: View {
    let threats: [SecurityThreat]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Security Alert")
                        .font(.headline)

                    Text("\(threats.count) threat(s) require your attention")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink {
                    SecurityView()
                } label: {
                    Text("Review")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(threats.prefix(3)) { threat in
                    HStack {
                        Circle()
                            .fill(severityColor(threat.severity))
                            .frame(width: 8, height: 8)

                        Text(threat.name)
                            .font(.caption)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(severityText(threat.severity))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if threats.count > 3 {
                    Text("And \(threats.count - 3) more...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private func severityColor(_ severity: ThreatSeverity) -> Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }

    private func severityText(_ severity: ThreatSeverity) -> String {
        switch severity {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Errors Card

struct ErrorsCard: View {
    let errors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("Some Tasks Failed")
                    .font(.headline)

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(errors.prefix(3), id: \.self) { error in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if errors.count > 3 {
                    Text("And \(errors.count - 3) more errors...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
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

// MARK: - Onboarding

struct OnboardingView: View {
    @ObservedObject var viewModel: SmartCareViewModel
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, description: String, gradient: [Color])] = [
        (
            icon: "wand.and.stars",
            title: "Welcome to Smart Care",
            description: "The easiest way to keep your Mac running smoothly. Smart Care combines multiple optimization tasks into one powerful tool.",
            gradient: [.blue, .purple]
        ),
        (
            icon: "internaldrive",
            title: "Automatic Cleanup",
            description: "Smart Care automatically finds and removes system caches, logs, and temporary files that slow down your Mac.",
            gradient: [.blue, .cyan]
        ),
        (
            icon: "memorychip",
            title: "Memory Optimization",
            description: "Free up RAM by clearing inactive memory and reducing memory pressure for better performance.",
            gradient: [.purple, .pink]
        ),
        (
            icon: "shield.checkered",
            title: "Security Scanning",
            description: "Check for malware, adware, and suspicious files automatically. Low-risk threats are removed automatically.",
            gradient: [.green, .blue]
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                OnboardingPage(
                    icon: pages[currentPage].icon,
                    title: pages[currentPage].title,
                    description: pages[currentPage].description,
                    gradient: pages[currentPage].gradient
                )
                .frame(height: 400)
                .animation(.easeInOut, value: currentPage)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.vertical, 16)

                // Actions
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            viewModel.completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .frame(width: 550, height: 520)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(16)
            .shadow(radius: 30)
        }
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(.title)
                .fontWeight(.bold)

            Text(description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    SmartCareView()
        .environmentObject(AppState.shared)
        .frame(width: 800, height: 600)
}
