import SwiftUI

/// A destructive action waiting on the user's confirmation. The project holds
/// at most one of these at a time; presenting it is the only way any text is
/// thrown away while `confirmDestructiveActions` is on.
struct ConfirmationRequest: Identifiable, Equatable {
    enum Action: Equatable {
        case clearVideo
        case removeBlock
    }

    let id = UUID()
    let action: Action

    var title: String {
        switch action {
        case .clearVideo: return "Clear video and text?"
        case .removeBlock: return "Remove text block?"
        }
    }

    var message: String {
        switch action {
        case .clearVideo:
            return "This unloads the video and clears every text block. Your font, colors, background, and padding are kept."
        case .removeBlock:
            return "This removes the selected block, along with the text in it."
        }
    }

    var confirmTitle: String {
        switch action {
        case .clearVideo: return "Clear"
        case .removeBlock: return "Remove"
        }
    }
}

/// Confirmation sheet for destructive actions. Built by hand rather than with
/// `.confirmationDialog` because neither an alert nor a dialog can carry the
/// "Don't ask me again" checkbox.
struct ConfirmationSheet: View {
    let request: ConfirmationRequest
    let onCancel: () -> Void
    let onConfirm: (_ suppressFuture: Bool) -> Void

    @State private var suppressFuture = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.large))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(request.title)
                        .font(.appRegularBold)
                    Text(request.message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle("Don't ask me again", isOn: $suppressFuture)
                .help("You can turn this warning back on in Settings.")

            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(request.confirmTitle, role: .destructive) {
                    onConfirm(suppressFuture)
                }
            }
        }
        .font(.appRegular)
        .padding(Spacing.xLarge)
        .frame(width: Metrics.sheetWidth)
    }
}
