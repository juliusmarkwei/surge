//
//  CleanupResultSheet.swift
//  SURGE
//
//  Displays cleanup results after completion.
//

import SwiftUI
import Shared

struct CleanupResultSheet: View {

    let result: CleanupResult?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Success icon
            if let result = result, result.errors.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
            }

            // Title
            Text(title)
                .font(.title)
                .fontWeight(.bold)

            // Details
            if let result = result {
                VStack(spacing: 16) {
                    // Stats
                    HStack(spacing: 32) {
                        StatBox(
                            label: "Files Deleted",
                            value: "\(result.deletedCount)",
                            icon: "trash.fill"
                        )

                        StatBox(
                            label: "Space Freed",
                            value: formatBytes(result.freedSpace),
                            icon: "internaldrive.fill"
                        )
                    }

                    // Errors
                    if !result.errors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Errors (\(result.errors.count))")
                                .font(.headline)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(result.errors, id: \.self) { error in
                                        Text("• \(error)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxHeight: 100)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            // Done button
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 400)
    }

    private var title: String {
        guard let result = result else {
            return "Cleanup Failed"
        }

        if result.errors.isEmpty {
            return "Cleanup Complete!"
        } else {
            return "Cleanup Completed with Errors"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    CleanupResultSheet(result: CleanupResult(
        deletedCount: 42,
        freedSpace: 1_500_000_000,
        errors: []
    ))
}

#Preview("With Errors") {
    CleanupResultSheet(result: CleanupResult(
        deletedCount: 38,
        freedSpace: 1_200_000_000,
        errors: [
            "Failed to delete /Library/Caches/item1.cache",
            "Failed to delete /Library/Caches/item2.cache"
        ]
    ))
}
