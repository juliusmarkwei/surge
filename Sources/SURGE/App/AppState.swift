//
//  AppState.swift
//  SURGE
//
//  Global application state management.
//

import SwiftUI
import Combine
import Shared

@MainActor
class AppState: ObservableObject {

    static let shared = AppState()

    // MARK: - Published Properties

    @Published var systemStats: SystemStats?
    @Published var isHelperInstalled: Bool = false
    @Published var isHelperConnected: Bool = false
    @Published var lastUpdateTime: Date = Date()
    @Published var error: String?

    // MARK: - Services

    let xpcClient = XPCClient.shared
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Poll XPC connection status periodically
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    let connected = await self.xpcClient.isConnected
                    await MainActor.run {
                        self.isHelperConnected = connected
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Helper Management

    func initializeHelperConnection() async {
        do {
            try await xpcClient.connect()
            isHelperInstalled = true

            // Ping to verify
            try await xpcClient.ping()

            // Get initial stats
            await refreshSystemStats()

        } catch {
            self.error = "Failed to connect to helper: \(error.localizedDescription)"
            isHelperInstalled = false
        }
    }

    func installHelper() async {
        do {
            try await HelperInstaller.shared.install()
            isHelperInstalled = true
            await initializeHelperConnection()
        } catch {
            self.error = "Failed to install helper: \(error.localizedDescription)"
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // Update stats every 3 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshSystemStats()
            }
        }
    }

    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refreshSystemStats() async {
        guard isHelperConnected else { return }

        do {
            let stats = try await xpcClient.getSystemStats()
            systemStats = stats
            lastUpdateTime = Date()
        } catch {
            // Silently fail - don't spam errors
            if self.systemStats == nil {
                self.error = "Failed to get system stats"
            }
        }
    }

    // MARK: - Window Management

    func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
