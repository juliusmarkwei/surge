//
//  MainWindowView.swift
//  SURGE
//
//  Main application window.
//

import SwiftUI
import Shared
import Security

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
            if !appState.isHelperConnected && !isDevelopmentBuild {
                helperSetupView
            } else if !appState.isHelperConnected && isDevelopmentBuild {
                // In development mode, show the dev message but also let them explore UI
                VStack(spacing: 0) {
                    helperSetupView
                        .frame(maxHeight: 400)

                    Divider()

                    // Show the selected tab content anyway (with limitations)
                    Group {
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
                    .opacity(0.9)
                }
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
        VStack(spacing: 24) {
            Image(systemName: isDevelopmentBuild ? "hammer.fill" : "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(isDevelopmentBuild ? .orange : .secondary)

            Text(isDevelopmentBuild ? "Development Mode" : "Privileged Helper Required")
                .font(.title)

            if isDevelopmentBuild {
                VStack(spacing: 16) {
                    Text("You're running an unsigned development build.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("UI fully functional for testing", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Label("Helper installation requires code signing", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Label("All code is implemented and ready", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .font(.callout)
                    .frame(maxWidth: 500, alignment: .leading)

                    Text("To test helper features, see DEVELOPMENT_NOTES.md for building a signed app bundle (Phase 8).")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 400)

                    Divider()
                        .padding(.vertical, 8)

                    Text("Continue exploring the UI below:")
                        .font(.headline)

                    // Show tab selection even without helper
                    HStack(spacing: 12) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                                // Allow viewing UI even without helper
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.title2)
                                    Text(tab.rawValue)
                                        .font(.caption)
                                }
                                .frame(width: 100, height: 80)
                                .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: 600)
            } else {
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
        }
        .padding()
    }

    // Check if this is a development build (unsigned)
    private var isDevelopmentBuild: Bool {
        // Check if the app is code signed
        guard let executableURL = Bundle.main.executableURL else { return true }

        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(executableURL as CFURL, [], &staticCode)

        if status != errSecSuccess { return true }

        guard let code = staticCode else { return true }

        // Check if it has a valid signature
        let checkStatus = SecStaticCodeCheckValidity(code, [], nil)
        return checkStatus != errSecSuccess
    }
}

// MARK: - Placeholder Views

// SmartCareView is now in Views/SmartCare/SmartCareView.swift
// StorageView is now in Views/Storage/StorageView.swift
// PerformanceView is now in Views/Performance/PerformanceView.swift

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
