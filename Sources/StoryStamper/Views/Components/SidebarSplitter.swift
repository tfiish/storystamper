import AppKit
import SwiftUI

/// The divider beside the style sidebar, made draggable. The sidebar resizes
/// within a clamped range rather than collapsing to nothing, because every
/// control in it—slider plus readout, segmented pickers, the padding hint—has
/// a width below which it starts wrapping badly.
///
/// Reachable by keyboard as well as by mouse. Sidebar width is the one thing
/// the app can do that has no menu item, so without this it would be the one
/// thing a keyboard user could not do at all—and it already had a spoken name,
/// which made it announce a control that could not then be operated.
struct SidebarSplitter: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    /// Which side the sidebar is on: dragging toward it makes it wider.
    var onCommit: (() -> Void)?

    @State private var widthAtDragStart: CGFloat?
    @FocusState private var focused: Bool

    var body: some View {
        Divider()
            .overlay {
                Color.clear
                    .frame(width: Metrics.splitterHitWidth)
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
                                resize(to: start - value.translation.width)
                            }
                            .onEnded { _ in
                                widthAtDragStart = nil
                                onCommit?()
                            }
                    )
                    .focusable()
                    .focused($focused)
                    .focusEffectDisabled()
                    .focusHalo(focused, shape: RoundedRectangle(cornerRadius: Radius.small))
                    // Left widens, matching the drag direction rather than the
                    // arrow's own direction: the key does what dragging that
                    // way would do.
                    .onKeyPress(keys: [.leftArrow, .rightArrow], phases: [.down, .repeat]) { press in
                        step(press.key == .leftArrow ? Spacing.large : -Spacing.large)
                    }
                    .accessibilityLabel("Resize style sidebar")
                    .accessibilityValue("\(Int(width)) points")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: step(Spacing.large)
                        case .decrement: step(-Spacing.large)
                        @unknown default: break
                        }
                    }
            }
    }

    private func resize(to proposed: CGFloat) {
        width = min(max(proposed, range.lowerBound), range.upperBound)
    }

    /// A keyboard change is its own commit: there is no drag end to wait for,
    /// and each press is a deliberate adjustment worth keeping.
    @discardableResult
    private func step(_ delta: CGFloat) -> KeyPress.Result {
        let before = width
        resize(to: width + delta)
        guard width != before else { return .handled }
        onCommit?()
        return .handled
    }
}
