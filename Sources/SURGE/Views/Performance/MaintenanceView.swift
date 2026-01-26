//
//  MaintenanceView.swift
//  SURGE
//
//  Run system maintenance tasks
//

import SwiftUI
import Shared

struct MaintenanceView: View {

    @StateObject private var viewModel = MaintenanceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if viewModel.isRunning {
                runningView
            } else if let result = viewModel.lastResult {
                resultView(result)
            } else {
                selectionView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Maintenance")
                    .font(.headline)

                if let lastRun = viewModel.lastRunDate {
                    Text("Last run: \(lastRun.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !viewModel.isRunning {
                Button {
                    Task {
                        await viewModel.runSelectedTasks()
                    }
                } label: {
                    Label("Run Selected", systemImage: "play.fill")
                }
                .disabled(viewModel.selectedTasks.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 0) {
            // Info banner
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)

                Text("Select maintenance tasks to run. These operations help keep your system running smoothly.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))

            Divider()

            // Tasks list
            List {
                ForEach(MaintenanceTask.allCases, id: \.self) { task in
                    MaintenanceTaskRow(
                        task: task,
                        isSelected: viewModel.selectedTasks.contains(task),
                        onToggle: {
                            viewModel.toggleTask(task)
                        }
                    )
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Running View

    private var runningView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Running Maintenance Tasks...")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(Array(viewModel.selectedTasks.enumerated()), id: \.element) { index, task in
                    HStack {
                        Text(taskName(task))
                            .font(.body)

                        Spacer()

                        if index < viewModel.currentTaskIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if index == viewModel.currentTaskIndex {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result View

    private func resultView(_ result: MaintenanceResult) -> some View {
        VStack(spacing: 0) {
            // Summary banner
            HStack {
                Image(systemName: result.failedTasks.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(result.failedTasks.isEmpty ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.failedTasks.isEmpty ? "Maintenance Complete" : "Maintenance Completed with Errors")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(result.completedTasks.count) tasks completed • \(result.failedTasks.count) failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    viewModel.clearResult()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(result.failedTasks.isEmpty ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))

            Divider()

            // Detailed results
            ScrollView {
                VStack(spacing: 16) {
                    // Completed tasks
                    if !result.completedTasks.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Completed Tasks", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)

                                ForEach(result.completedTasks, id: \.self) { task in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)

                                        Text(taskName(task))
                                            .font(.body)

                                        Spacer()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Failed tasks
                    if !result.failedTasks.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Failed Tasks", systemImage: "xmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.red)

                                ForEach(result.failedTasks, id: \.self) { task in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)

                                            Text(taskName(task))
                                                .font(.body)

                                            Spacer()
                                        }

                                        if let error = result.errors.first(where: { $0.contains(taskName(task)) }) {
                                            Text(error)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 24)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func taskName(_ task: MaintenanceTask) -> String {
        switch task {
        case .rebuildSpotlight:
            return "Rebuild Spotlight Index"
        case .rebuildLaunchServices:
            return "Rebuild Launch Services"
        case .clearDNSCache:
            return "Clear DNS Cache"
        case .repairPermissions:
            return "Repair Disk Permissions"
        case .verifyDisk:
            return "Verify Disk"
        }
    }

    private func taskDescription(_ task: MaintenanceTask) -> String {
        switch task {
        case .rebuildSpotlight:
            return "Fixes Spotlight search issues by rebuilding the search index"
        case .rebuildLaunchServices:
            return "Fixes file association and Open With menu problems"
        case .clearDNSCache:
            return "Clears cached DNS entries to resolve connectivity issues"
        case .repairPermissions:
            return "Repairs disk permissions to fix access issues"
        case .verifyDisk:
            return "Checks disk for errors and attempts to repair them"
        }
    }
}

// MARK: - Maintenance Task Row

struct MaintenanceTaskRow: View {
    let task: MaintenanceTask
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .imageScale(.large)
                .onTapGesture {
                    onToggle()
                }

            // Icon
            Image(systemName: taskIcon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(taskName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(taskDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    private var taskIcon: String {
        switch task {
        case .rebuildSpotlight:
            return "magnifyingglass"
        case .rebuildLaunchServices:
            return "doc.on.doc"
        case .clearDNSCache:
            return "network"
        case .repairPermissions:
            return "lock.shield"
        case .verifyDisk:
            return "internaldrive"
        }
    }

    private var taskName: String {
        switch task {
        case .rebuildSpotlight:
            return "Rebuild Spotlight Index"
        case .rebuildLaunchServices:
            return "Rebuild Launch Services"
        case .clearDNSCache:
            return "Clear DNS Cache"
        case .repairPermissions:
            return "Repair Disk Permissions"
        case .verifyDisk:
            return "Verify Disk"
        }
    }

    private var taskDescription: String {
        switch task {
        case .rebuildSpotlight:
            return "Fixes Spotlight search issues"
        case .rebuildLaunchServices:
            return "Fixes file associations and Open With menu"
        case .clearDNSCache:
            return "Resolves DNS and connectivity issues"
        case .repairPermissions:
            return "Repairs disk permissions"
        case .verifyDisk:
            return "Checks and repairs disk errors"
        }
    }
}

// MARK: - View Model

@MainActor
class MaintenanceViewModel: ObservableObject {

    @Published var selectedTasks: [MaintenanceTask] = []
    @Published var isRunning: Bool = false
    @Published var currentTaskIndex: Int = 0
    @Published var lastResult: MaintenanceResult?
    @Published var lastRunDate: Date?

    func toggleTask(_ task: MaintenanceTask) {
        if selectedTasks.contains(task) {
            selectedTasks.removeAll { $0 == task }
        } else {
            selectedTasks.append(task)
        }
    }

    func runSelectedTasks() async {
        guard !selectedTasks.isEmpty && !isRunning else { return }

        isRunning = true
        currentTaskIndex = 0
        lastResult = nil

        do {
            let result = try await XPCClient.shared.runMaintenance(tasks: selectedTasks)
            lastResult = result
            lastRunDate = Date()
        } catch {
            print("Maintenance failed: \(error)")

            // Create error result
            lastResult = MaintenanceResult(
                completedTasks: [],
                failedTasks: selectedTasks,
                errors: [error.localizedDescription]
            )
        }

        isRunning = false
    }

    func clearResult() {
        lastResult = nil
        selectedTasks = []
    }
}
