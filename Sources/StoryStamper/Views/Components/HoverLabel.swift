import SwiftUI

/// The app's own tooltip.
///
/// `.help()` routes through AppKit's tooltip manager, whose delay is roughly a
/// second and is not settable through any public API. Every named control here
/// draws its own instead, so hovering feels the same everywhere rather than
/// fast on some controls and sluggish on others.
private struct HoverLabelModifier: ViewModifier {
    let text: String
    let edge: VerticalEdge

    @State private var task: Task<Void, Never>?
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in hover(inside) }
            .overlay(alignment: edge == .top ? .top : .bottom) { label }
    }

    @ViewBuilder
    private var label: some View {
        if showing {
            Text(text)
                .font(.appSmall)
                .foregroundStyle(.primary)
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
                .alignmentGuide(edge == .top ? .top : .bottom) { box in
                    edge == .top ? box[.bottom] + Spacing.tight : box[.top] - Spacing.tight
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(1)
        }
    }

    private func hover(_ inside: Bool) {
        task?.cancel()
        guard inside else {
            withAnimation(.easeOut(duration: Motion.quick)) { showing = false }
            return
        }
        task = Task {
            try? await Task.sleep(for: .seconds(Motion.tooltipDelay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Motion.quick)) { showing = true }
        }
    }
}

extension View {
    /// Names this control on hover, after `Motion.tooltipDelay`.
    ///
    /// Pass `.bottom` where the control sits at the top of its container and a
    /// label above it would be clipped.
    func hoverLabel(_ text: String, edge: VerticalEdge = .top) -> some View {
        modifier(HoverLabelModifier(text: text, edge: edge))
    }
}
