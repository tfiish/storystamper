import AppKit
import SwiftUI

/// A visible focus indicator for controls that draw themselves—anything using
/// `.buttonStyle(.plain)` or a custom shape—since those get no system focus
/// ring.
///
/// Drawn as a soft halo *outside* the control's bounds. Selection, where a
/// control has it, is drawn inside and at full strength, so the two never read
/// as the same state.
///
/// It appears for keyboard focus only. Clicking a control also focuses it, and
/// ringing it then announced something the person had just done with their own
/// mouse—on a three-segment picker it read like a validation error around a
/// control that was working perfectly. Tabbing in still rings it, which is the
/// only case the halo was ever for.
private struct FocusHaloModifier<Outline: InsettableShape>: ViewModifier {
    let isFocused: Bool
    let outline: Outline

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .overlay {
                outline
                    .strokeBorder(Color.accentColor.opacity(Opacity.focusHalo), lineWidth: FocusHalo.width)
                    .padding(-FocusHalo.inset)
                    .opacity(isVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .onChange(of: isFocused, initial: true) { _, focused in
                isVisible = focused && !Self.focusFollowedAClick
            }
    }

    /// Whatever AppKit is dispatching as focus moves is what moved it. Only a
    /// mouse press counts as a click; anything else—including an event we did
    /// not think of—shows the halo, so the failure is a ring nobody needed
    /// rather than a keyboard user with no idea where they are.
    @MainActor
    private static var focusFollowedAClick: Bool {
        switch NSApp.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp:
            return true
        default:
            return false
        }
    }
}

extension View {
    /// Marks this control as holding keyboard focus, for controls the system
    /// draws no focus ring around.
    func focusHalo(_ isFocused: Bool, shape: some InsettableShape) -> some View {
        modifier(FocusHaloModifier(isFocused: isFocused, outline: shape))
    }
}
