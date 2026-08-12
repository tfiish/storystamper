import SwiftUI

/// The one place a failure is shown, whichever half of the app produced it.
/// The message is always selectable: an FFmpeg exit status is something people
/// copy into an issue, and having to retype it is the whole complaint.
struct FailureSheet: View {
    let failure: StoryFailure
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: IconSize.status))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(failure.title)
                .font(.appRegularBold)

            Text(failure.message)
                .font(.appRegular)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Metrics.sheetTextWidth)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Button("Close") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(Spacing.xLarge)
        .frame(minWidth: Metrics.sheetMinWidth)
    }
}
