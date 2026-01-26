//
//  SecurityView.swift
//  SURGE
//
//  Security scanner for malware and adware detection
//

import SwiftUI
import Shared

struct SecurityView: View {

    @StateObject private var viewModel = SecurityViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if viewModel.isScanning {
                scanningView
            } else if viewModel.threats.isEmpty && !viewModel.hasScanned {
                welcomeView
            } else if viewModel.threats.isEmpty {
                cleanView
            } else {
                threatsListView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Security Scanner")
                    .font(.headline)

                if let lastScan = viewModel.lastScanDate {
                    Text("Last scan: \(lastScan.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No scans performed yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Database info
            if let dbInfo = viewModel.databaseInfo {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Signatures: \(dbInfo.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("v\(dbInfo.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }

            Button {
                Task {
                    await viewModel.scan()
                }
            } label: {
                Label("Scan Now", systemImage: "shield.checkered")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning)
        }
        .padding()
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Protect Your Mac")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Scan for malware, adware, and suspicious files that may compromise your security and privacy.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 12) {
                SecurityFeatureRow(icon: "magnifyingglass", text: "Signature-based malware detection")
                SecurityFeatureRow(icon: "safari", text: "Browser extension scanning")
                SecurityFeatureRow(icon: "gearshape.2", text: "Persistence location checking")
                SecurityFeatureRow(icon: "doc.text.magnifyingglass", text: "Heuristic analysis")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            Button {
                Task {
                    await viewModel.scan()
                }
            } label: {
                Label("Start Security Scan", systemImage: "play.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning for Threats...")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ScanStepRow(title: "Checking persistence locations", isActive: true)
                ScanStepRow(title: "Scanning browser extensions", isActive: true)
                ScanStepRow(title: "Analyzing suspicious files", isActive: true)
                ScanStepRow(title: "Matching signatures", isActive: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clean View

    private var cleanView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("No Threats Detected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your Mac appears to be clean. No malware, adware, or suspicious files were found.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            Button {
                Task {
                    await viewModel.scan()
                }
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Threats List View

    private var threatsListView: some View {
        VStack(spacing: 0) {
            // Threat summary
            threatSummary

            Divider()

            // Threats list
            List(viewModel.threats) { threat in
                ThreatRow(
                    threat: threat,
                    onRemove: {
                        Task {
                            await viewModel.removeThreat(threat)
                        }
                    }
                )
            }
        }
    }

    private var threatSummary: some View {
        HStack {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(summaryColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.threats.count) Threat\(viewModel.threats.count == 1 ? "" : "s") Found")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(threatBreakdown)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                viewModel.confirmRemoveAll()
            } label: {
                Label("Remove All", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .disabled(viewModel.threats.isEmpty)
        }
        .padding()
        .background(summaryColor.opacity(0.1))
    }

    private var summaryColor: Color {
        let criticalCount = viewModel.threats.filter { $0.severity == .critical }.count
        let highCount = viewModel.threats.filter { $0.severity == .high }.count

        if criticalCount > 0 {
            return .red
        } else if highCount > 0 {
            return .orange
        } else {
            return .yellow
        }
    }

    private var threatBreakdown: String {
        let byType = Dictionary(grouping: viewModel.threats, by: { $0.type })
        var parts: [String] = []

        if let malware = byType[.malware], !malware.isEmpty {
            parts.append("\(malware.count) malware")
        }
        if let adware = byType[.adware], !adware.isEmpty {
            parts.append("\(adware.count) adware")
        }
        if let persistence = byType[.suspiciousPersistence], !persistence.isEmpty {
            parts.append("\(persistence.count) suspicious")
        }
        if let extensions = byType[.browserExtension], !extensions.isEmpty {
            parts.append("\(extensions.count) extension\(extensions.count == 1 ? "" : "s")")
        }

        return parts.joined(separator: " • ")
    }
}

// MARK: - Security Feature Row

struct SecurityFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.callout)

            Spacer()
        }
    }
}

// MARK: - Scan Step Row

struct ScanStepRow: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack {
            if isActive {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            Text(title)
                .font(.body)
                .foregroundColor(isActive ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Threat Row

struct ThreatRow: View {
    let threat: SecurityThreat
    let onRemove: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text(threat.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                HStack {
                    Text(threat.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        NSWorkspace.shared.selectFile(threat.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
            }
        } label: {
            HStack(spacing: 12) {
                // Severity indicator
                Circle()
                    .fill(severityColor)
                    .frame(width: 12, height: 12)

                // Icon
                Image(systemName: typeIcon)
                    .font(.title3)
                    .foregroundColor(severityColor)
                    .frame(width: 24)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(threat.name)
                        .font(.body)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Text(typeName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(severityColor.opacity(0.2))
                            .cornerRadius(4)

                        Text(severityText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Remove button
                Button {
                    confirmRemove()
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }

    private var typeIcon: String {
        switch threat.type {
        case .malware:
            return "exclamationmark.shield.fill"
        case .adware:
            return "megaphone.fill"
        case .suspiciousPersistence:
            return "questionmark.diamond.fill"
        case .browserExtension:
            return "safari.fill"
        }
    }

    private var typeName: String {
        switch threat.type {
        case .malware:
            return "Malware"
        case .adware:
            return "Adware"
        case .suspiciousPersistence:
            return "Suspicious"
        case .browserExtension:
            return "Browser Extension"
        }
    }

    private var severityColor: Color {
        switch threat.severity {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }

    private var severityText: String {
        switch threat.severity {
        case .low:
            return "Low Risk"
        case .medium:
            return "Medium Risk"
        case .high:
            return "High Risk"
        case .critical:
            return "Critical"
        }
    }

    private func confirmRemove() {
        let alert = NSAlert()
        alert.messageText = "Remove \(threat.name)?"
        alert.informativeText = "This will move the threat to quarantine. You can recover it later if this is a false positive."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            onRemove()
        }
    }
}

// MARK: - View Model

@MainActor
class SecurityViewModel: ObservableObject {

    @Published var threats: [SecurityThreat] = []
    @Published var isScanning: Bool = false
    @Published var hasScanned: Bool = false
    @Published var lastScanDate: Date?
    @Published var databaseInfo: (version: String, count: Int)?

    func scan() async {
        isScanning = true
        threats = []

        do {
            let result = try await XPCClient.shared.scanForMalware()
            threats = result
            lastScanDate = Date()
            hasScanned = true

            // Get database info (would need to add this to XPC protocol)
            // For now, use placeholder
            databaseInfo = ("1.0.0", 12)

        } catch {
            print("Security scan failed: \(error)")

            let alert = NSAlert()
            alert.messageText = "Scan Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }

        isScanning = false
    }

    func removeThreat(_ threat: SecurityThreat) async {
        do {
            try await XPCClient.shared.removeThreat(threat)

            // Remove from list
            threats.removeAll { $0.id == threat.id }

            // Show success
            let notification = NSAlert()
            notification.messageText = "Threat Removed"
            notification.informativeText = "\(threat.name) has been moved to quarantine."
            notification.alertStyle = .informational
            notification.runModal()

        } catch {
            print("Failed to remove threat: \(error)")

            let alert = NSAlert()
            alert.messageText = "Removal Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    func confirmRemoveAll() {
        let alert = NSAlert()
        alert.messageText = "Remove All \(threats.count) Threats?"
        alert.informativeText = "All detected threats will be moved to quarantine. This action can be undone by restoring from quarantine."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                await removeAllThreats()
            }
        }
    }

    private func removeAllThreats() async {
        let threatsToRemove = threats

        for threat in threatsToRemove {
            await removeThreat(threat)
        }
    }
}
