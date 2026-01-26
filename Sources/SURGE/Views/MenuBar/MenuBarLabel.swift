//
//  MenuBarLabel.swift
//  SURGE
//
//  Menu bar icon and label.
//

import SwiftUI

struct MenuBarLabel: View {

    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)

            if let stats = appState.systemStats {
                Text(String(format: "%.0f%%", stats.cpuUsage))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(colorForCPU(stats.cpuUsage))
            }
        }
    }

    private var iconName: String {
        if !appState.isHelperConnected {
            return "exclamationmark.triangle"
        }

        guard let stats = appState.systemStats else {
            return "chart.bar"
        }

        // Change icon based on CPU usage
        if stats.cpuUsage < 30 {
            return "chart.bar"
        } else if stats.cpuUsage < 70 {
            return "chart.bar.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }

    private func colorForCPU(_ usage: Double) -> Color {
        if usage < 60 {
            return .primary
        } else if usage < 80 {
            return .orange
        } else {
            return .red
        }
    }
}
