import SwiftUI

/// A labelled slider with a fixed-width readout beside it. Three of these sat
/// in the style sidebar as three near-identical constructions, which is how
/// their formatting and accessibility drifted apart in the first place.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Drives both the visible readout and the spoken value, so the two can
    /// never disagree.
    let format: (Double) -> String
    /// Spoken name, when the visible label is too terse on its own—two
    /// sections both have a row called "Color".
    var spokenName: String?
    var help: String?

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: Spacing.small) {
                slider
                Text(format(value))
                    .font(.appSmallDigits)
                    .frame(width: Metrics.readoutWidth, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var slider: some View {
        let base = Slider(value: $value, in: range)
            .accessibilityLabel(spokenName ?? title)
            .accessibilityValue(format(value))
        if let help {
            base.hoverLabel(help)
        } else {
            base
        }
    }
}
