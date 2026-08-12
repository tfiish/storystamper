import SwiftUI

/// Plain-language overview shown from the sidebar's About button.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "text.below.photo")
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
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
                HStack(spacing: 4) {
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
            .padding(.top, 2)
        }
        .font(.appRegular)
        .padding(24)
        .frame(width: 420)
    }
}
