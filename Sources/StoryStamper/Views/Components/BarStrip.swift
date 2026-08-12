import SwiftUI

/// A strip pinned to the edge of a pane, sitting on the bar material: both
/// sidebar footers, and the transport controls under the video. One component
/// so the three cannot drift apart in padding or material.
struct BarStrip<Content: View>: View {
    /// Override only where the strip spans a pane much wider than a sidebar,
    /// which today means the transport bar alone. The default is what the two
    /// sidebar footers use, and a third answer here would be drift.
    var horizontalPadding: CGFloat = Spacing.medium
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, Spacing.medium)
            .background(.bar)
    }
}
