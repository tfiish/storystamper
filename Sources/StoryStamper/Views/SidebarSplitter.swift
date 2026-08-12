import AppKit
import SwiftUI

/// The divider beside the style sidebar, made draggable. The sidebar resizes
/// within a clamped range rather than collapsing to nothing, because every
/// control in it—slider plus readout, segmented pickers, the padding hint—has
/// a width below which it starts wrapping badly.
struct SidebarSplitter: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    /// Which side the sidebar is on: dragging toward it makes it wider.
    var onCommit: (() -> Void)?

    @State private var widthAtDragStart: CGFloat?

    /// Wider than the hairline so the drag target is reachable without
    /// pixel-hunting, which is the usual complaint about hand-rolled splitters.
    private let hitWidth: CGFloat = 8

    var body: some View {
        Divider()
            .overlay {
                Color.clear
                    .frame(width: hitWidth)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside {
                            NSCursor.resizeLeftRight.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let start = widthAtDragStart ?? width
                                if widthAtDragStart == nil { widthAtDragStart = start }
                                // The sidebar sits to the right, so dragging
                                // left widens it.
                                width = min(max(start - value.translation.width, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in
                                widthAtDragStart = nil
                                onCommit?()
                            }
                    )
                    .accessibilityLabel("Resize style sidebar")
            }
    }
}
