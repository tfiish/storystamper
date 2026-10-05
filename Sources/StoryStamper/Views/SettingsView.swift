import SwiftUI

/// Preferences that are not part of styling a clip, reached from the sidebar
/// footer. Deliberately small: what an export costs, what Return does once it
/// finishes, and nothing else. This is not a second control panel.
struct SettingsView: View {
    @Bindable var project: StoryProject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            SheetTitle("Settings")

            Divider()

            VStack(alignment: .leading, spacing: Spacing.small) {
                Picker("Export Size", selection: $project.exportResolution) {
                    ForEach(ExportResolution.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Text("Instagram serves Stories at 1080 \u{00D7} 1920. Exporting a 4K clip at 4K takes far longer than exporting at 1080p, and is not rendered at 4K in a Story. (Sources below 1080p are never upscaled.)")
                    .font(.appSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.small) {
                Picker("Return After Export", selection: $project.exportCompletionAction) {
                    ForEach(ExportCompletionAction.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Text("Set which button Return (Enter) will select on an export confirmation popup. \u{201C}Clear Video\u{201D} empties the window so the next clip can be loaded in straight away (without touching the exported file or the original).")
                    .font(.appSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .sheetChrome(width: Metrics.sheetWidth)
    }
}
