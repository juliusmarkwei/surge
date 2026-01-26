//
//  StartupItemsView.swift
//  SURGE
//
//  Manage startup items (Launch Agents, Daemons, Login Items)
//

import SwiftUI
import Shared

struct StartupItemsView: View {

    @StateObject private var viewModel = StartupItemsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredItems.isEmpty {
                emptyView
            } else {
                itemsListView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Startup Items")
                    .font(.headline)

                Text("\(viewModel.filteredItems.count) items • \(viewModel.enabledCount) enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.loadItems()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack {
            // Type filter
            Picker("", selection: $viewModel.filterType) {
                Text("All Types").tag(StartupFilterType.all)
                Text("Launch Agents").tag(StartupFilterType.launchAgents)
                Text("Launch Daemons").tag(StartupFilterType.launchDaemons)
                Text("Login Items").tag(StartupFilterType.loginItems)
            }
            .labelsHidden()
            .frame(width: 150)

            Divider()

            // Status filter
            Picker("", selection: $viewModel.filterStatus) {
                Text("All Status").tag(StartupFilterStatus.all)
                Text("Enabled").tag(StartupFilterStatus.enabled)
                Text("Disabled").tag(StartupFilterStatus.disabled)
            }
            .labelsHidden()
            .frame(width: 120)

            Divider()

            // System filter
            Toggle("Hide System Items", isOn: $viewModel.hideSystemItems)
                .toggleStyle(.checkbox)
                .font(.caption)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Items List

    private var itemsListView: some View {
        List(viewModel.filteredItems) { item in
            StartupItemRow(
                item: item,
                onToggle: {
                    Task {
                        await viewModel.toggleItem(item)
                    }
                }
            )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading startup items...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No startup items found")
                .foregroundColor(.secondary)

            if viewModel.hideSystemItems || viewModel.filterType != .all || viewModel.filterStatus != .all {
                Button {
                    viewModel.filterType = .all
                    viewModel.filterStatus = .all
                    viewModel.hideSystemItems = false
                } label: {
                    Text("Clear Filters")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Startup Item Row

struct StartupItemRow: View {
    let item: StartupItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: typeIcon)
                .font(.title3)
                .foregroundColor(typeColor)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(item.isSystemItem ? .regular : .medium)

                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Type badge
                    Text(typeName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.2))
                        .cornerRadius(4)

                    // System badge
                    if item.isSystemItem {
                        Text("System")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { item.enabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .disabled(item.isSystemItem)
        }
        .padding(.vertical, 4)
        .opacity(item.enabled ? 1.0 : 0.6)
    }

    private var typeIcon: String {
        switch item.type {
        case .launchAgent:
            return "person.crop.circle"
        case .launchDaemon:
            return "gearshape.2"
        case .loginItem:
            return "rectangle.inset.filled.and.person.crop"
        }
    }

    private var typeName: String {
        switch item.type {
        case .launchAgent:
            return "Launch Agent"
        case .launchDaemon:
            return "Launch Daemon"
        case .loginItem:
            return "Login Item"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .launchAgent:
            return .blue
        case .launchDaemon:
            return .purple
        case .loginItem:
            return .green
        }
    }
}

// MARK: - Filter Types

enum StartupFilterType {
    case all
    case launchAgents
    case launchDaemons
    case loginItems
}

enum StartupFilterStatus {
    case all
    case enabled
    case disabled
}

// MARK: - View Model

@MainActor
class StartupItemsViewModel: ObservableObject {

    @Published var items: [StartupItem] = []
    @Published var isLoading: Bool = false
    @Published var filterType: StartupFilterType = .all
    @Published var filterStatus: StartupFilterStatus = .all
    @Published var hideSystemItems: Bool = false

    var filteredItems: [StartupItem] {
        items
            .filter { item in
                // Type filter
                switch filterType {
                case .all:
                    break
                case .launchAgents:
                    guard item.type == .launchAgent else { return false }
                case .launchDaemons:
                    guard item.type == .launchDaemon else { return false }
                case .loginItems:
                    guard item.type == .loginItem else { return false }
                }

                // Status filter
                switch filterStatus {
                case .all:
                    break
                case .enabled:
                    guard item.enabled else { return false }
                case .disabled:
                    guard !item.enabled else { return false }
                }

                // System filter
                if hideSystemItems && item.isSystemItem {
                    return false
                }

                return true
            }
    }

    var enabledCount: Int {
        items.filter { $0.enabled }.count
    }

    init() {
        Task {
            await loadItems()
        }
    }

    func loadItems() async {
        isLoading = true

        do {
            let result = try await XPCClient.shared.getStartupItems()
            items = result
        } catch {
            print("Failed to load startup items: \(error)")
        }

        isLoading = false
    }

    func toggleItem(_ item: StartupItem) async {
        do {
            let newState = !item.enabled

            try await XPCClient.shared.setStartupItemEnabled(
                item: item,
                enabled: newState
            )

            // Update local state
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                var updatedItem = items[index]
                updatedItem = StartupItem(
                    id: updatedItem.id,
                    name: updatedItem.name,
                    path: updatedItem.path,
                    type: updatedItem.type,
                    enabled: newState,
                    isSystemItem: updatedItem.isSystemItem
                )
                items[index] = updatedItem
            }

        } catch {
            print("Failed to toggle startup item: \(error)")

            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Failed to modify startup item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
