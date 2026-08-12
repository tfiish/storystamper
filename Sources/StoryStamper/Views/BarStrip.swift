import SwiftUI

/// A strip pinned to the edge of a pane, sitting on the bar material: both
/// sidebar footers, and the transport controls under the video. One component
/// so the three cannot drift apart in padding or material.
struct BarStrip<Content: View>: View {
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
