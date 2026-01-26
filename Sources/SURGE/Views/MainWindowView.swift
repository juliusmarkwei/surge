//
//  MainWindowView.swift
//  SURGE
//
//  Main application window.
//

import SwiftUI
import Shared

struct MainWindowView: View {

    @EnvironmentObject var appState: AppState

    @State private var selectedTab: Tab = .smartCare

    enum Tab: String, CaseIterable {
        case smartCare = "Smart Care"
        case storage = "Storage"
        case performance = "Performance"
        case security = "Security"

        var icon: String {
            switch self {
            case .smartCare: return "wand.and.stars"
            case .storage: return "internaldrive"
            case .performance: return "speedometer"
            case .security: return "shield.checkered"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarView
        } detail: {
            // Main content
            contentView
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("SURGE")
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        Group {
            if !appState.isHelperConnected {
                helperSetupView
            } else {
                switch selectedTab {
                case .smartCare:
                    SmartCareView()
                case .storage:
                    StorageView()
                case .performance:
                    PerformanceView()
                case .security:
                    SecurityView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Setup

    private var helperSetupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Privileged Helper Required")
                .font(.title)

            Text("SURGE requires a privileged helper tool to perform system operations.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            Button("Install Helper") {
                Task {
                    await appState.installHelper()
                }
            }
            .buttonStyle(.borderedProminent)

            if let error = appState.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: 400)
            }
        }
        .padding()
    }
}

// MARK: - Placeholder Views

// SmartCareView is now in Views/SmartCare/SmartCareView.swift
// StorageView is now in Views/Storage/StorageView.swift

struct PerformanceView: View {
    var body: some View {
        VStack {
            Text("Performance")
                .font(.largeTitle)
            Text("RAM optimization and monitoring coming soon")
                .foregroundColor(.secondary)
        }
    }
}

struct SecurityView: View {
    var body: some View {
        VStack {
            Text("Security")
                .font(.largeTitle)
            Text("Malware scanner coming soon")
                .foregroundColor(.secondary)
        }
    }
}
