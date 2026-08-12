import SwiftUI

/// A row of glyphs where exactly one is chosen: font, alignment, and theme.
///
/// Hand-built rather than a `Picker(.segmented)` for three reasons a segmented
/// picker cannot give us. It reduces a `Text` to a plain segment label and
/// applies its own font, which is why four styled specimens came out
/// identical. It draws no focus ring we can reach. And it cannot caption
/// itself.
///
/// A caption under the row names the current choice outright, because a line
/// of symbols never says in words which one is on.
struct GlyphPicker<Value: Hashable, Glyph: View>: View {
    /// Spoken name of the control itself, e.g. "Font".
    let title: String
    @Binding var selection: Value
    let items: [Value]
    /// Human-readable name of one option, used for the caption, the hover
    /// label, and the accessibility value.
    let name: (Value) -> String
    @ViewBuilder let glyph: (Value) -> Glyph

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Spacing.tight) {
            segments
            caption
        }
    }

    /// Laid out as one cell per segment so the name sits under the glyph it
    /// belongs to. The cells are placeholders and the text is drawn over them
    /// at its natural width, so a long name stays on one line rather than
    /// being squeezed into a 30-point column.
    ///
    /// Interior names center on their segment. The first and last pin to the
    /// outer edge instead, so they grow inward—centering those would push the
    /// text past the control's own bounds, where the row around it clips.
    private var caption: some View {
        HStack(spacing: BorderWidth.hairline) {
            ForEach(items, id: \.self) { item in
                Color.clear
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: captionAlignment(for: item)) {
                        if item == selection {
                            Text(name(item))
                                .font(.appSmall)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
            }
        }
        .padding(.horizontal, BorderWidth.emphasis)
        .frame(height: Metrics.captionHeight)
        .accessibilityHidden(true)
    }

    private func captionAlignment(for item: Value) -> Alignment {
        guard let index = items.firstIndex(of: item) else { return .center }
        if index == items.startIndex { return .leading }
        if index == items.index(before: items.endIndex) { return .trailing }
        return .center
    }

    private var segments: some View {
        HStack(spacing: BorderWidth.hairline) {
            ForEach(items, id: \.self) { item in
                segment(item)
            }
        }
        .padding(BorderWidth.emphasis)
        .background {
            RoundedRectangle(cornerRadius: Radius.small)
                .fill(.quaternary)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .focusHalo(focused, shape: RoundedRectangle(cornerRadius: Radius.small))
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            move(by: press.key == .leftArrow ? -1 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(name(selection))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: _ = move(by: 1)
            case .decrement: _ = move(by: -1)
            @unknown default: break
            }
        }
    }

    private func segment(_ item: Value) -> some View {
        let isSelected = item == selection
        return glyph(item)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.segmentHeight)
            .background {
                RoundedRectangle(cornerRadius: Radius.small - BorderWidth.emphasis)
                    .fill(Color(nsColor: .controlColor))
                    .shadow(color: .black.opacity(Opacity.segmentShadow), radius: BorderWidth.hairline)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { selection = item }
            .accessibilityHidden(true)
    }

    private func move(by offset: Int) -> KeyPress.Result {
        guard let index = items.firstIndex(of: selection) else { return .ignored }
        let next = index + offset
        guard items.indices.contains(next) else { return .handled }
        selection = items[next]
        return .handled
    }
}
