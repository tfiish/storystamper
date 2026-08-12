import SwiftUI

/// An icon-only button.
///
/// The spoken label is required rather than optional, which is the point: an
/// icon-only control cannot be built here without a name for it. It also
/// carries its own focus halo, since `.buttonStyle(.plain)` strips the
/// system's.
///
/// There used to be a second style, a dark disc for floating over video. Its
/// only caller was the X that cleared the video, and 2.0.1 moved that into the
/// left sidebar as a named button—so the disc, its ring, and the question of
/// what shade either should be all went with it.
struct IconButton: View {
    let systemName: String
    /// Shown on hover and read aloud by VoiceOver.
    let label: String
    var glyphSize: CGFloat = IconSize.medium
    var glyphWeight: Font.Weight = .regular
    /// Optional, and nullable on purpose: a caller can withdraw the shortcut
    /// while a text field has focus.
    var shortcut: KeyboardShortcut?
    let action: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: glyphSize, weight: glyphWeight))
                .frame(width: Metrics.overlayButton, height: Metrics.overlayButton)
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
