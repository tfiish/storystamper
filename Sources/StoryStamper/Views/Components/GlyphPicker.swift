import AppKit
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
    /// Human-readable name of one option, used for the caption and for the
    /// accessibility value.
    let name: (Value) -> String
    @ViewBuilder let glyph: (Value) -> Glyph

    @FocusState private var focused: Bool
    /// Width of the control, measured rather than assumed: the caption cannot
    /// be placed under a segment without knowing how wide a segment is. Nil
    /// until the first layout.
    @State private var controlWidth: CGFloat?

    var body: some View {
        VStack(spacing: Spacing.tight) {
            segments
            caption
        }
    }

    /// One line naming the current choice, centered under the glyph it names.
    private var caption: some View {
        Text(name(selection))
            .font(.appSmall)
            .foregroundStyle(.secondary)
            .fixedSize()
            .offset(x: captionOffset)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.captionHeight)
            .accessibilityHidden(true)
    }

    /// How far the caption sits from the control's center: on the selected
    /// segment's center, then pulled back in by however much it would
    /// otherwise hang off the end of the control.
    ///
    /// Both halves of that are needed. A name wider than its own segment has
    /// to overhang, and under the first or last segment that overhang would
    /// leave the control, where the row around it clips—which is what an
    /// unconditional pin to the outer edge used to prevent. The pin paid for
    /// it with every name that fitted: "Dark", under the third of three
    /// segments, sat eleven points to the right of the moon it named. Clamping
    /// only where there is genuinely no room moves nothing that fits, and
    /// moves "Monospace" by about twelve points instead of twenty-four.
    private var captionOffset: CGFloat {
        guard let controlWidth,
              let index = items.firstIndex(of: selection) else { return 0 }

        let inner = controlWidth - BorderWidth.emphasis * 2
        let gaps = BorderWidth.hairline * CGFloat(items.count - 1)
        let segment = (inner - gaps) / CGFloat(items.count)
        let segmentCenter = CGFloat(index) * (segment + BorderWidth.hairline) + segment / 2

        let room = inner / 2 - CaptionWidth.of(name(selection)) / 2
        // A name wider than the whole control cannot be kept inside it, and
        // the least bad place for that is the middle.
        guard room > 0 else { return 0 }
        return min(max(segmentCenter - inner / 2, -room), room)
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
        .background {
            // Measured around the segments rather than the whole picker,
            // because the segments are what the caption lines up with.
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.width, initial: true) { _, width in
                        controlWidth = width
                    }
            }
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

/// Caption widths, measured once each and kept.
///
/// `Font.appSmall` is the system font at `TextSize.small`, so AppKit measures
/// exactly what SwiftUI will draw—which is what lets the caption be placed
/// without a second layout pass to discover how wide it came out.
@MainActor
private enum CaptionWidth {
    private static var cache: [String: CGFloat] = [:]

    static func of(_ text: String) -> CGFloat {
        if let cached = cache[text] { return cached }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: TextSize.small)]
        let width = NSAttributedString(string: text, attributes: attributes).size().width
        cache[text] = width
        return width
    }
}
