import SwiftUI

/// One-click preset swatches followed by the system color picker for anything
/// else. The active preset gets a ring and a tick—two channels, so selection
/// never rests on color alone.
///
/// The swatches carry no hover label. They are the one kind of icon-only
/// control that already shows what it does, so a tooltip naming the color said
/// nothing the swatch had not. They still carry a spoken label.
struct ColorRow: View {
    let presets: [ColorSwatch]
    @Binding var selection: RGBAColor

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(presets) { preset in
                SwatchButton(preset: preset, isSelected: selection.matches(preset.color)) {
                    selection = preset.color
                }
            }

            ColorPicker(
                "Custom color",
                selection: Binding(
                    get: { selection.color },
                    set: { selection = RGBAColor(color: $0) }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            // macOS's color panel has no OK button—it applies as you pick—so
            // say that rather than leave people hunting for one. As a hint
            // rather than a hover label: nothing in this row draws a tooltip,
            // and the swatches beside it gave theirs up for the same reason.
            .accessibilityHint("Changes apply as you pick. Close the panel when you are done.")
        }
    }
}

private struct SwatchButton: View {
    let preset: ColorSwatch
    let isSelected: Bool
    let action: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(preset.color.color)
                .frame(width: Metrics.swatch, height: Metrics.swatch)
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(Opacity.border), lineWidth: BorderWidth.hairline)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: BorderWidth.emphasis)
                        .padding(-Spacing.tight)
                        .opacity(isSelected ? 1 : 0)
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: IconSize.badge, weight: .bold))
                            .foregroundStyle(preset.color.isLight ? Color.black : Color.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .focused($focused)
        .focusEffectDisabled()
        .focusHalo(focused, shape: Circle())
        // No hover label: the swatch shows the colour, and the ring and tick
        // show which one is on, so naming it on hover only repeated them.
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
