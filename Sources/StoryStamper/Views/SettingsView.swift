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
                Toggle("Confirm before clearing text", isOn: $project.confirmDestructiveActions)
                Text("Asks first when the X on the video or the Remove button would throw away text you have typed. Turning this off is what the \u{201C}Don't ask me again\u{201D} checkbox does.")
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
