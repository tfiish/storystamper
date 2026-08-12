import SwiftUI

/// Preferences that are not part of styling a clip, reached from the sidebar
/// footer. Deliberately small—this is where a suppressed warning is turned
/// back on, not a second control panel.
struct SettingsView: View {
    @Bindable var project: StoryProject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Settings")
                .font(.appTitle)

            Divider()

            VStack(alignment: .leading, spacing: Spacing.small) {
                Toggle("Confirm before deletion", isOn: $project.confirmDestructiveActions)
                Text("Enables confirmation pop-up before clearing a video or text. Clicking \u{201C}Don't ask me again\u{201D} on that popup disables this.")
                    .font(.appSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.small) {
                Picker("Export size", selection: $project.exportResolution) {
                    ForEach(ExportResolution.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Text("Instagram serves Stories at 1080 \u{00D7} 1920. Exporting a 4K clip at 4K takes far longer and uploads far more, for pixels that get thrown away. Sources at or below 1080 are never enlarged.")
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
