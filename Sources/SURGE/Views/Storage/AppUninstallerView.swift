//
//  AppUninstallerView.swift
//  SURGE
//
//  Complete application uninstaller with associated files
//

import SwiftUI
import Shared

struct AppUninstallerView: View {

    @StateObject private var viewModel = AppUninstallerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Search bar
            searchBar

            Divider()

            // Content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredApps.isEmpty {
                emptyView
            } else {
                appsListView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Uninstall Applications")
                    .font(.headline)

                if !viewModel.apps.isEmpty {
                    Text("\(viewModel.filteredApps.count) apps • \(formatBytes(viewModel.totalSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                Task {
                    await viewModel.loadApps()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search applications...", text: $viewModel.searchText)
                .textFieldStyle(.plain)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Apps List

    private var appsListView: some View {
        List(viewModel.filteredApps) { app in
            AppRow(
                app: app,
                onUninstall: {
                    viewModel.confirmUninstall(app)
                }
            )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading applications...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(viewModel.searchText.isEmpty ? "No applications found" : "No matching applications")
                .foregroundColor(.secondary)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Text("Clear Search")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: InstalledApp
    let onUninstall: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Associated files
            if !app.associatedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associated Files (\(app.associatedFiles.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    ForEach(app.associatedFiles, id: \.self) { filePath in
                        HStack {
                            Image(systemName: "doc")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(filePath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.leading, 16)
                    }

                    Text("Total with files: \(formatBytes(app.totalSize))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // App icon placeholder
                Image(systemName: "app.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)

                // App info
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.headline)

                    if let version = app.version {
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(app.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Size and uninstall button
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatBytes(app.size))
                        .font(.caption)
                        .fontWeight(.medium)

                    Button {
                        onUninstall()
                    } label: {
                        Label("Uninstall", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - ViewModel

@MainActor
class AppUninstallerViewModel: ObservableObject {

    @Published var apps: [InstalledApp] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var error: String?

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return apps
        } else {
            return apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var totalSize: UInt64 {
        filteredApps.reduce(0) { $0 + $1.totalSize }
    }

    init() {
        Task {
            await loadApps()
        }
    }

    func loadApps() async {
        isLoading = true
        error = nil

        do {
            let result = try await XPCClient.shared.listInstalledApps()
            apps = result
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func confirmUninstall(_ app: InstalledApp) {
        let alert = NSAlert()
        alert.messageText = "Uninstall \(app.name)?"
        alert.informativeText = """
        This will permanently remove the application and its associated files.

        App size: \(formatBytes(app.size))
        Total size (with files): \(formatBytes(app.totalSize))

        Associated files: \(app.associatedFiles.count)

        This action cannot be undone.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                await uninstall(app)
            }
        }
    }

    private func uninstall(_ app: InstalledApp) async {
        do {
            try await XPCClient.shared.uninstallApp(app)

            // Remove from list
            apps.removeAll { $0.id == app.id }

            // Show success notification
            let notification = NSAlert()
            notification.messageText = "Success"
            notification.informativeText = "\(app.name) was uninstalled successfully."
            notification.alertStyle = .informational
            notification.runModal()

        } catch {
            self.error = error.localizedDescription

            // Show error
            let alert = NSAlert()
            alert.messageText = "Uninstall Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
