import SwiftUI

/// A row of glyphs where exactly one is chosen: font, alignment, and theme.
///
/// Hand-built rather than a `Picker(.segmented)` for three reasons a segmented
/// picker cannot give us. It reduces a `Text` to a plain segment label and
/// applies its own font, which is why four styled specimens came out
/// identical. It offers no way to attach hover to an individual segment, so
/// naming a glyph means the system tooltip and its unsettable delay. And it
/// draws no focus ring we can reach.
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

    @State private var hoverTask: Task<Void, Never>?
    @State private var hovered: Value?
    @State private var named: Value?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.tight) {
            segments
            Text(name(selection))
                .font(.appSmall)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
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
        .overlay(alignment: .top) { hoverLabel }
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
            .onHover { inside in hover(item, inside: inside) }
            .accessibilityHidden(true)
    }

    /// The app's own tooltip. `.help()` would route through AppKit's tooltip
    /// manager, whose delay is roughly a second and is not publicly settable.
    @ViewBuilder
    private var hoverLabel: some View {
        if let named {
            Text(name(named))
                .font(.appSmall)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.hair)
                .background {
                    RoundedRectangle(cornerRadius: Radius.small)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.small)
                                .strokeBorder(Color.primary.opacity(Opacity.border), lineWidth: BorderWidth.hairline)
                        }
                }
                .fixedSize()
                .offset(y: -(Metrics.segmentHeight + Spacing.small))
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func hover(_ item: Value, inside: Bool) {
        hoverTask?.cancel()
        guard inside else {
            if hovered == item {
                hovered = nil
                withAnimation(.easeOut(duration: Motion.quick)) { named = nil }
            }
            return
        }
        hovered = item
        hoverTask = Task {
            try? await Task.sleep(for: .seconds(Motion.tooltipDelay))
            guard !Task.isCancelled, hovered == item else { return }
            withAnimation(.easeOut(duration: Motion.quick)) { named = item }
        }
    }

    private func move(by offset: Int) -> KeyPress.Result {
        guard let index = items.firstIndex(of: selection) else { return .ignored }
        let next = index + offset
        guard items.indices.contains(next) else { return .handled }
        selection = items[next]
        return .handled
    }
}
