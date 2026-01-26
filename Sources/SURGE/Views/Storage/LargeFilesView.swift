//
//  LargeFilesView.swift
//  SURGE
//
//  Find and manage large and old files
//

import SwiftUI
import Shared

struct LargeFilesView: View {

    @StateObject private var viewModel = LargeFilesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Filters
            filtersBar

            Divider()

            // Content
            if viewModel.isScanning {
                scanningView
            } else if viewModel.filteredFiles.isEmpty {
                emptyView
            } else {
                filesListView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Large & Old Files")
                    .font(.headline)

                if !viewModel.files.isEmpty {
                    Text("\(viewModel.filteredFiles.count) files • \(formatBytes(viewModel.totalSize))")
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

    // MARK: - Filters

    private var filtersBar: some View {
        HStack {
            // Size filter
            VStack(alignment: .leading, spacing: 4) {
                Text("Minimum Size")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.minSizeFilter) {
                    Text("50 MB").tag(UInt64(52_428_800))
                    Text("100 MB").tag(UInt64(104_857_600))
                    Text("500 MB").tag(UInt64(524_288_000))
                    Text("1 GB").tag(UInt64(1_073_741_824))
                }
                .labelsHidden()
                .frame(width: 100)
            }

            Divider()

            // Age filter
            VStack(alignment: .leading, spacing: 4) {
                Text("Minimum Age")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.minAgeFilter) {
                    Text("90 days").tag(90)
                    Text("6 months").tag(180)
                    Text("1 year").tag(365)
                    Text("2 years").tag(730)
                }
                .labelsHidden()
                .frame(width: 100)
            }

            Spacer()

            // Sort options
            Menu {
                Picker("Sort By", selection: $viewModel.sortOption) {
                    Label("Size (Largest)", systemImage: "arrow.down").tag(SortOption.sizeDescending)
                    Label("Size (Smallest)", systemImage: "arrow.up").tag(SortOption.sizeAscending)
                    Label("Age (Oldest)", systemImage: "clock").tag(SortOption.ageDescending)
                    Label("Age (Newest)", systemImage: "clock.fill").tag(SortOption.ageAscending)
                    Label("Name", systemImage: "textformat").tag(SortOption.name)
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Files List

    private var filesListView: some View {
        VStack(spacing: 0) {
            // Selection bar
            HStack {
                Text("\(viewModel.selectedFileIDs.count) files selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !viewModel.selectedFileIDs.isEmpty {
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

            // Files
            List(viewModel.filteredFiles, selection: $viewModel.selectedFileIDs) { file in
                LargeFileRow(file: file)
            }
        }
    }

    // MARK: - States

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanning for large files...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No large files found")
                .foregroundColor(.secondary)

            Text("Select a folder and click Scan to find large and old files")
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

// MARK: - Large File Row

struct LargeFileRow: View {
    let file: LargeFileItem

    var body: some View {
        HStack {
            Image(systemName: fileIcon(for: file.name))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)

                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    Text("\(file.ageInDays) days old")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("Modified: \(file.modificationDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formatBytes(file.size))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()

        switch ext {
        case "mov", "mp4", "avi", "mkv":
            return "film"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        case "dmg", "iso":
            return "opticaldiscdrive"
        case "pdf":
            return "doc.text"
        default:
            return "doc"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - ViewModel

enum SortOption {
    case sizeDescending
    case sizeAscending
    case ageDescending
    case ageAscending
    case name
}

@MainActor
class LargeFilesViewModel: ObservableObject {

    @Published var files: [LargeFileItem] = []
    @Published var isScanning: Bool = false
    @Published var scanPath: String = NSHomeDirectory()
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var minSizeFilter: UInt64 = 104_857_600 // 100MB
    @Published var minAgeFilter: Int = 365 // 1 year
    @Published var sortOption: SortOption = .sizeDescending
    @Published var error: String?

    var filteredFiles: [LargeFileItem] {
        let filtered = files.filter { file in
            file.size >= minSizeFilter && file.ageInDays >= minAgeFilter
        }

        switch sortOption {
        case .sizeDescending:
            return filtered.sorted { $0.size > $1.size }
        case .sizeAscending:
            return filtered.sorted { $0.size < $1.size }
        case .ageDescending:
            return filtered.sorted { $0.ageInDays > $1.ageInDays }
        case .ageAscending:
            return filtered.sorted { $0.ageInDays < $1.ageInDays }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var totalSize: UInt64 {
        filteredFiles.reduce(0) { $0 + $1.size }
    }

    func scan() async {
        isScanning = true
        error = nil
        files = []
        selectedFileIDs = []

        do {
            // Call XPC service
            let result = try await XPCClient.shared.findLargeOldFiles(
                paths: [scanPath],
                minSize: minSizeFilter,
                minAge: minAgeFilter
            )

            files = result
        } catch {
            self.error = error.localizedDescription
        }

        isScanning = false
    }

    func deleteSelected() {
        let selectedPaths = files.filter { selectedFileIDs.contains($0.id) }.map { $0.path }

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

            // Remove deleted files
            files.removeAll { file in selectedFileIDs.contains(file.id) }
            selectedFileIDs.removeAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func calculateSelectedSize() -> UInt64 {
        files.filter { selectedFileIDs.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
