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
                .foregroundStyle(Palette.warning)
                .accessibilityHidden(true)

            SheetTitle(failure.title)

            Text(failure.message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Metrics.sheetTextWidth)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Button("Done") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .sheetChrome()
        // The sheet replaces whatever was on screen without moving focus, so
        // without this a screen reader is told nothing at all about a failure.
        .announced("\(failure.title). \(failure.message)")
    }
}
