import SwiftUI

/// An icon-only button.
///
/// The spoken label is required rather than optional, which is the point: an
/// icon-only control cannot be built here without a name for it. It also
/// carries its own focus halo, since `.buttonStyle(.plain)` strips the
/// system's.
struct IconButton: View {
    enum Style {
        /// Sits on the window background and takes its color from it.
        case plain
        /// Floats over video, so it brings its own dark backing.
        case scrim
    }

    let systemName: String
    /// Shown on hover and read aloud by VoiceOver.
    let label: String
    var glyphSize: CGFloat = IconSize.medium
    var glyphWeight: Font.Weight = .regular
    var style: Style = .plain
    /// Optional, and nullable on purpose: a caller can withdraw the shortcut
    /// while a text field has focus.
    var shortcut: KeyboardShortcut?
    let action: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: glyphSize, weight: glyphWeight))
                .foregroundStyle(style == .scrim ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: Metrics.overlayButton, height: Metrics.overlayButton)
                .background {
                    if style == .scrim {
                        Circle()
                            .fill(Color.black.opacity(Opacity.scrim))
                            .overlay {
                                // Full white, matching the glyph inside it. A
                                // faint ring read as a smudge on the video
                                // rather than as the edge of a control; the
                                // dark fill is what separates the two.
                                Circle().strokeBorder(Color.white, lineWidth: BorderWidth.hairline)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut)
        .focused($focused)
        .focusEffectDisabled()
        .focusHalo(focused, shape: Circle())
        .hoverLabel(label)
        .accessibilityLabel(label)
    }
}
