import SwiftUI

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
                .hoverLabel("You can turn this warning back on in Settings.", edge: .bottom)

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
