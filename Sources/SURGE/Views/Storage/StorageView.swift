//
//  StorageView.swift
//  SURGE
//
//  Main storage management view with cleanup functionality.
//

import SwiftUI
import Shared

struct StorageView: View {

    @StateObject private var viewModel = StorageViewModel()
    @ObservedObject private var coordinator = CleanupCoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main content
            if coordinator.isScanning {
                scanningView
            } else if coordinator.cleanableItems.isEmpty {
                emptyStateView
            } else {
                cleanupContentView
            }
        }
        .sheet(isPresented: $viewModel.showingCleanupPreview) {
            CleanupPreviewSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingCleanupResult) {
            CleanupResultSheet(result: viewModel.lastCleanupResult)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Management")
                    .font(.title)
                    .fontWeight(.bold)

                if let lastScan = coordinator.lastScanDate {
                    Text("Last scan: \(viewModel.formatDate(lastScan))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                Task {
                    await viewModel.performScan()
                }
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.isScanning)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "internaldrive")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Scan Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Scan your system to find cleanable files and free up disk space.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            Button {
                Task {
                    await viewModel.performScan()
                }
            } label: {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 24) {
            ProgressView(value: coordinator.scanProgress) {
                Text("Scanning...")
                    .font(.title2)
            } currentValueLabel: {
                Text("\(Int(coordinator.scanProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 300)

            Text("Finding cleanable files on your system")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cleanup Content

    private var cleanupContentView: some View {
        HSplitView {
            // Left: Categories
            categoriesSidebar

            // Right: Items list
            itemsListView
        }
    }

    // MARK: - Categories Sidebar

    private var categoriesSidebar: some View {
        VStack(spacing: 0) {
            // Select all/none
            HStack {
                Button("All") {
                    coordinator.selectAllCategories()
                }
                .buttonStyle(.plain)
                .font(.caption)

                Text("•")
                    .foregroundColor(.secondary)

                Button("None") {
                    coordinator.deselectAllCategories()
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Category list
            List {
                ForEach(CleanupCategory.allCases, id: \.self) { category in
                    CategoryRow(
                        category: category,
                        isSelected: coordinator.selectedCategories.contains(category),
                        items: coordinator.itemsByCategory[category] ?? [],
                        onToggle: {
                            coordinator.toggleCategory(category)
                        }
                    )
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Summary and action
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(viewModel.formatBytes(coordinator.totalSize))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)

                    Text(viewModel.formatItemCount(coordinator.selectedItems.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    viewModel.previewCleanup()
                } label: {
                    Label("Review & Clean", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.selectedItems.isEmpty)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)
    }

    // MARK: - Items List

    private var itemsListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(coordinator.selectedItems.count) items")
                    .font(.headline)

                Spacer()

                Menu {
                    Button("Size (Largest First)") { }
                    Button("Size (Smallest First)") { }
                    Button("Date (Newest First)") { }
                    Button("Date (Oldest First)") { }
                    Button("Name (A-Z)") { }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.callout)
                }
                .menuStyle(.borderlessButton)
            }
            .padding()

            Divider()

            // Items list
            if coordinator.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No items selected")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(coordinator.selectedItems) { item in
                    CleanableItemRow(item: item, viewModel: viewModel)
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: CleanupCategory
    let isSelected: Bool
    let items: [CleanableItem]
    let onToggle: () -> Void

    private var totalSize: UInt64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                    .font(.body)

                Text(formatBytes(totalSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(items.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
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

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Cleanable Item Row

struct CleanableItemRow: View {
    let item: CleanableItem
    let viewModel: StorageViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForItem)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.path.split(separator: "/").last.map(String.init) ?? item.path)
                    .font(.body)

                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.formatBytes(item.size))
                    .font(.callout)
                    .monospacedDigit()

                Text(viewModel.formatDate(item.lastModified))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconForItem: String {
        switch item.category {
        case .systemCaches, .userCaches: return "folder.fill"
        case .logs: return "doc.text.fill"
        case .trash: return "trash.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .developerJunk: return "hammer.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    StorageView()
        .frame(width: 900, height: 600)
}
