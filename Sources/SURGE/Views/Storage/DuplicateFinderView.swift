//
//  DuplicateFinderView.swift
//  SURGE
//
//  Duplicate file finder with SHA-256 content hashing
//

import SwiftUI
import Shared

struct DuplicateFinderView: View {

    @StateObject private var viewModel = DuplicateFinderViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if viewModel.isScanning {
                scanningView
            } else if viewModel.groups.isEmpty {
                emptyView
            } else {
                duplicatesListView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Files")
                    .font(.headline)

                if !viewModel.groups.isEmpty {
                    Text("\(viewModel.groups.count) groups • \(formatBytes(viewModel.totalWastedSpace)) wasted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Menu {
                Button {
                    viewModel.scanPath = NSHomeDirectory()
                } label: {
                    Label("Home Directory", systemImage: "house")
                }

                Button {
                    viewModel.scanPath = NSHomeDirectory() + "/Downloads"
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

                Button {
                    viewModel.scanPath = NSHomeDirectory() + "/Documents"
                } label: {
                    Label("Documents", systemImage: "doc")
                }

                Divider()

                Button {
                    selectCustomPath()
                } label: {
                    Label("Choose Folder...", systemImage: "folder")
                }
            } label: {
                Text(viewModel.scanPath)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
            }

            Button {
                Task {
                    await viewModel.scan()
                }
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(viewModel.isScanning)
        }
        .padding()
    }

    // MARK: - Duplicates List

    private var duplicatesListView: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Text("\(viewModel.selectedFilesCount) files selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.selectedFilesCount > 0 {
                    Button {
                        viewModel.deleteSelected()
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Groups list
            List(viewModel.groups, selection: $viewModel.selectedFileIDs) {
                group in
                DuplicateGroupRow(group: group, selectedFileIDs: $viewModel.selectedFileIDs)
            }
        }
    }

    // MARK: - States

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanning for duplicates...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No duplicates found")
                .foregroundColor(.secondary)

            Text("Select a folder and click Scan to find duplicate files")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func selectCustomPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanPath = url.path
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - Duplicate Group Row

struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    @Binding var selectedFileIDs: Set<UUID>
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(group.files) { file in
                HStack {
                    Toggle(isOn: Binding(
                        get: { selectedFileIDs.contains(file.id) },
                        set: { isSelected in
                            if isSelected {
                                selectedFileIDs.insert(file.id)
                            } else {
                                selectedFileIDs.remove(file.id)
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.body)

                            Text(file.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Text("Modified: \(file.modificationDate.formatted())")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)

                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.vertical, 4)
            }
        } label: {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.fileCount) identical files")
                        .font(.headline)

                    Text("\(formatBytes(group.wastedSpace)) wasted space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatBytes(group.files.first?.size ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - ViewModel

@MainActor
class DuplicateFinderViewModel: ObservableObject {

    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning: Bool = false
    @Published var scanPath: String = NSHomeDirectory()
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var error: String?

    var totalWastedSpace: UInt64 {
        groups.reduce(0) { $0 + $1.wastedSpace }
    }

    var selectedFilesCount: Int {
        selectedFileIDs.count
    }

    func scan() async {
        isScanning = true
        error = nil
        groups = []
        selectedFileIDs = []

        do {
            // Call XPC service
            let result = try await XPCClient.shared.findDuplicates(
                paths: [scanPath],
                minSize: 1_048_576 // 1MB minimum
            )

            groups = result
        } catch {
            self.error = error.localizedDescription
        }

        isScanning = false
    }

    func deleteSelected() {
        // Get paths of selected files
        let selectedPaths = groups.flatMap { group in
            group.files.filter { selectedFileIDs.contains($0.id) }.map { $0.path }
        }

        guard !selectedPaths.isEmpty else { return }

        // Confirm deletion
        let alert = NSAlert()
        alert.messageText = "Delete \(selectedPaths.count) files?"
        alert.informativeText = "This will free up approximately \(formatBytes(calculateSelectedSize())) of space."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                await performDeletion(paths: selectedPaths)
            }
        }
    }

    private func performDeletion(paths: [String]) async {
        do {
            let result = try await XPCClient.shared.deleteFiles(
                paths: paths,
                useQuarantine: true
            )

            // Remove deleted files from groups
            await scan() // Re-scan to update
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func calculateSelectedSize() -> UInt64 {
        var total: UInt64 = 0
        for group in groups {
            for file in group.files where selectedFileIDs.contains(file.id) {
                total += file.size
            }
        }
        return total
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
