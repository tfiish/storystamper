import Foundation

/// One text overlay: its content, its style, and its center in normalized
/// (0...1) video coordinates.
struct OverlayBlock: Identifiable, Equatable {
    let id: UUID
    var text: String
    var style: OverlayStyle
    var center: CGPoint

    init(id: UUID = UUID(), text: String = "", style: OverlayStyle, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.id = id
        self.text = text
        self.style = style
        self.center = center
    }

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
