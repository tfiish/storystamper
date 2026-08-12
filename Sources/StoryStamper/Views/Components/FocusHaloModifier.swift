import SwiftUI

extension View {
    /// A visible focus indicator for controls that draw themselves—anything
    /// using `.buttonStyle(.plain)` or a custom shape—since those get no
    /// system focus ring.
    ///
    /// Drawn as a soft halo *outside* the control's bounds. Selection, where a
    /// control has it, is drawn inside and at full strength, so the two never
    /// read as the same state.
    func focusHalo(_ isFocused: Bool, shape: some InsettableShape) -> some View {
        overlay {
            shape
                .strokeBorder(Color.accentColor.opacity(Opacity.focusHalo), lineWidth: FocusHalo.width)
                .padding(-FocusHalo.inset)
                .opacity(isFocused ? 1 : 0)
                .allowsHitTesting(false)
        }
    }
}
