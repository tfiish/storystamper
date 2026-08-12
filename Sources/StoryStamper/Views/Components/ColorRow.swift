import SwiftUI

/// One-click preset swatches followed by the system color picker for anything
/// else. The active preset gets a ring and a tick—two channels, so selection
/// never rests on color alone.
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
            // say that rather than leave people hunting for one.
            .hoverLabel("Changes apply as you pick; close the panel when you are done.")
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
        .hoverLabel(preset.name)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
