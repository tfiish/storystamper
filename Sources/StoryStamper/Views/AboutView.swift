import SwiftUI

/// Plain-language overview shown from the sidebar's About button.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: "text.below.photo")
                    .font(.system(size: IconSize.large))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.hair) {
                    Text(AppInfo.displayName)
                        .font(.appTitle)
                    Text("Version \(AppInfo.version)")
                        .font(.appSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Story Stamper adds text—and only text—to a vertical video in the style of an Instagram Story, then burns it permanently into a new MP4.")

            Text("It exists for one workflow: stamping a video with text before you schedule it from Meta Business Suite. That way you never have to move the clip onto a phone just to add text and save it back.")

            Text("Everything runs locally on your Mac. Nothing is uploaded, no account is needed, and the original video is never modified.")

            if let url = AppInfo.repositoryURL {
                HStack(spacing: Spacing.tight) {
                    Text("Full details are in the README:")
                    Link("github.com/tfiish/storystamper", destination: url)
                }
                .font(.appRegular)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, Spacing.hair)
        }
        .font(.appRegular)
        .padding(Spacing.xLarge)
        .frame(width: Metrics.sheetWidth)
    }
}
