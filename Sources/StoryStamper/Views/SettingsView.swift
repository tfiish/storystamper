import SwiftUI

/// Preferences that are not part of styling a clip, reached from the sidebar
/// footer. Deliberately small: one setting that changes what an export costs,
/// and nothing else. This is not a second control panel.
struct SettingsView: View {
    @Bindable var project: StoryProject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Settings")
                .font(.appTitle)

            Divider()

            VStack(alignment: .leading, spacing: Spacing.small) {
                Picker("Export size", selection: $project.exportResolution) {
                    ForEach(ExportResolution.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Text("Instagram serves Stories at 1080 \u{00D7} 1920. Exporting a 4K clip at 4K takes far longer than exporting at 1080p, and is not rendered in an Instagram story. (Sources below 1080p are never upscaled.)")
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
        .font(.appRegular)
        .padding(Spacing.xLarge)
        .frame(width: Metrics.sheetWidth)
    }
}
