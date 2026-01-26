//
//  PerformanceView.swift
//  SURGE
//
//  Main performance view with tabs for monitoring, startup items, and maintenance
//

import SwiftUI

struct PerformanceView: View {

    @State private var selectedTab: PerformanceTab = .monitor

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Tab content
            tabContentView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Monitor system performance and optimize")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Tab selector
            Picker("", selection: $selectedTab) {
                ForEach(PerformanceTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
        }
        .padding()
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContentView: some View {
        switch selectedTab {
        case .monitor:
            PerformanceMonitorView()
        case .startupItems:
            StartupItemsView()
        case .maintenance:
            MaintenanceView()
        }
    }
}

// MARK: - Performance Tabs

enum PerformanceTab: String, CaseIterable, Identifiable {
    case monitor = "Monitor"
    case startupItems = "Startup Items"
    case maintenance = "Maintenance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monitor: return "Monitor"
        case .startupItems: return "Startup Items"
        case .maintenance: return "Maintenance"
        }
    }

    var icon: String {
        switch self {
        case .monitor: return "chart.xyaxis.line"
        case .startupItems: return "gearshape.2"
        case .maintenance: return "wrench.and.screwdriver"
        }
    }
}
