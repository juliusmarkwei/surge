//
//  CleanupPreviewSheet.swift
//  SURGE
//
//  Preview and confirmation sheet before cleanup.
//

import SwiftUI
import Shared

struct CleanupPreviewSheet: View {

    @ObservedObject var viewModel: StorageViewModel
    @ObservedObject private var coordinator = CleanupCoordinator.shared

    @Environment(\.dismiss) private var dismiss

    @State private var useQuarantine: Bool = true
    @State private var isPerformingCleanup: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            contentView

            Divider()

            // Footer
            footerView
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review Cleanup")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Please review the files that will be cleaned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 16) {
            // Summary cards
            HStack(spacing: 16) {
                SummaryCard(
                    icon: "trash.fill",
                    title: "Items to Clean",
                    value: "\(coordinator.selectedItems.count)",
                    color: .orange
                )

                SummaryCard(
                    icon: "internaldrive.fill",
                    title: "Space to Free",
                    value: viewModel.formatBytes(coordinator.totalSize),
                    color: .blue
                )

                SummaryCard(
                    icon: "clock.fill",
                    title: "Estimated Time",
                    value: formatTime(coordinator.estimatedCleanupTime()),
                    color: .green
                )
            }

            // Items by category
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(CleanupCategory.allCases, id: \.self) { category in
                        if let items = coordinator.itemsByCategory[category],
                           !items.isEmpty,
                           coordinator.selectedCategories.contains(category) {
                            CategoryPreviewSection(
                                category: category,
                                items: items,
                                viewModel: viewModel
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .padding()
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 16) {
            // Quarantine option
            Toggle(isOn: $useQuarantine) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Quarantine")
                        .font(.callout)

                    Text("Keep files for 30 days (recommended)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()

            // Actions
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if isPerformingCleanup {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 120)
            } else {
                Button {
                    performCleanup()
                } label: {
                    Label("Clean Now", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func performCleanup() {
        isPerformingCleanup = true

        Task {
            await viewModel.performCleanup(useQuarantine: useQuarantine)
            dismiss()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "< 1 min"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes) min"
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Category Preview Section

struct CategoryPreviewSection: View {
    let category: CleanupCategory
    let items: [CleanableItem]
    let viewModel: StorageViewModel

    @State private var isExpanded: Bool = false

    private var totalSize: UInt64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(categoryName)
                        .font(.headline)

                    Spacer()

                    Text("\(items.count) items • \(viewModel.formatBytes(totalSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            // Expanded items
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(items.prefix(10)) { item in
                        HStack {
                            Text("•")
                                .foregroundColor(.secondary)

                            Text(item.path.split(separator: "/").last.map(String.init) ?? item.path)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text(viewModel.formatBytes(item.size))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 2)
                    }

                    if items.count > 10 {
                        Text("... and \(items.count - 10) more items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var categoryName: String {
        switch category {
        case .systemCaches: return "System Caches"
        case .userCaches: return "User Caches"
        case .logs: return "Log Files"
        case .trash: return "Trash"
        case .downloads: return "Downloads"
        case .developerJunk: return "Developer Junk"
        }
    }
}
