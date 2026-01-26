//
//  TreeMapView.swift
//  SURGE
//
//  Interactive TreeMap disk space visualizer
//

import SwiftUI
import Shared

struct TreeMapView: View {

    @StateObject private var viewModel = TreeMapViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // TreeMap visualization
            if viewModel.isLoading {
                loadingView
            } else if let root = viewModel.rootItem {
                ZStack(alignment: .topLeading) {
                    // TreeMap rectangles
                    GeometryReader { geometry in
                        treeMapContent(root: root, size: geometry.size)
                    }

                    // Breadcrumb navigation
                    breadcrumbView
                        .padding()
                }
            } else {
                emptyView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk Space Visualizer")
                    .font(.headline)

                if let root = viewModel.rootItem {
                    Text("\(formatBytes(root.size)) in \(viewModel.currentPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Scan button
            Button {
                Task {
                    await viewModel.scanPath("/")
                }
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    // MARK: - TreeMap Content

    private func treeMapContent(root: TreeMapItem, size: CGSize) -> some View {
        let rectangles = TreeMapLayout.layout(
            item: viewModel.currentItem ?? root,
            in: CGRect(origin: .zero, size: size),
            minArea: 25.0  // Don't show rectangles smaller than 5x5 pixels
        )

        return ZStack(alignment: .topLeading) {
            ForEach(rectangles) { rect in
                TreeMapRectangleView(
                    rect: rect,
                    isSelected: viewModel.selectedItem?.id == rect.item.id,
                    onTap: {
                        viewModel.selectItem(rect.item)
                    },
                    onDoubleTap: {
                        if rect.item.isDirectory {
                            viewModel.drillDown(rect.item)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbView: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.navigationStack.indices, id: \.self) { index in
                Button {
                    viewModel.navigateTo(index: index)
                } label: {
                    Text(viewModel.navigationStack[index].name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                if index < viewModel.navigationStack.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Scanning disk...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Click Scan to visualize disk space")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - Rectangle View

struct TreeMapRectangleView: View {
    let rect: TreeMapRect
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        Rectangle()
            .fill(colorForItem(rect.item))
            .border(isSelected ? Color.accentColor : Color.white.opacity(0.3), width: isSelected ? 2 : 1)
            .overlay(alignment: .topLeading) {
                if rect.width > 60 && rect.height > 40 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rect.item.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(formatBytes(rect.item.size))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(4)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
            .onTapGesture {
                onTap()
            }
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
            .help(rect.item.path)
    }

    private func colorForItem(_ item: TreeMapItem) -> Color {
        let hue = Double(abs(item.name.hashValue) % 360) / 360.0
        let saturation = item.isDirectory ? 0.6 : 0.8
        let brightness = 0.7

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - ViewModel

@MainActor
class TreeMapViewModel: ObservableObject {

    @Published var rootItem: TreeMapItem?
    @Published var currentItem: TreeMapItem?
    @Published var selectedItem: TreeMapItem?
    @Published var navigationStack: [TreeMapItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    var currentPath: String {
        navigationStack.last?.path ?? "/"
    }

    func scanPath(_ path: String) async {
        isLoading = true
        error = nil

        // Simulate scanning (replace with XPC call)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Mock data for now
        let mockRoot = TreeMapItem(
            path: path,
            name: path == "/" ? "Root" : (path as NSString).lastPathComponent,
            size: 100_000_000_000,
            isDirectory: true,
            children: generateMockChildren(depth: 0)
        )

        rootItem = mockRoot
        currentItem = mockRoot
        navigationStack = [mockRoot]
        isLoading = false
    }

    func selectItem(_ item: TreeMapItem) {
        selectedItem = item
    }

    func drillDown(_ item: TreeMapItem) {
        guard item.isDirectory, let children = item.children, !children.isEmpty else { return }

        currentItem = item
        navigationStack.append(item)
        selectedItem = nil
    }

    func navigateTo(index: Int) {
        guard index < navigationStack.count else { return }

        navigationStack = Array(navigationStack.prefix(index + 1))
        currentItem = navigationStack.last
        selectedItem = nil
    }

    // Mock data generator
    private func generateMockChildren(depth: Int) -> [TreeMapItem]? {
        guard depth < 3 else { return nil }

        return (0..<5).map { i in
            let isDir = depth < 2
            return TreeMapItem(
                path: "/mock/path\(depth)/item\(i)",
                name: "Item \(i)",
                size: UInt64.random(in: 1_000_000...10_000_000_000),
                isDirectory: isDir,
                children: isDir ? generateMockChildren(depth: depth + 1) : nil
            )
        }
    }
}
