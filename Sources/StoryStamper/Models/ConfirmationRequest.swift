import Foundation

/// A destructive action waiting on the user's confirmation. The project holds
/// at most one of these at a time; presenting it is the only way any text is
/// thrown away while `confirmDestructiveActions` is on.
struct ConfirmationRequest: Identifiable, Equatable {
    enum Action: Equatable {
        /// `hasText` only chooses the wording. Whether to ask at all is the
        /// setting's business, not this type's.
        case clearVideo(hasText: Bool)
        case removeBlock
    }

    let id = UUID()
    let action: Action

    var title: String {
        switch action {
        case .clearVideo(let hasText):
            return hasText ? "Clear video and text?" : "Clear video?"
        case .removeBlock:
            return "Remove text block?"
        }
    }

    var message: String {
        switch action {
        case .clearVideo(let hasText):
            return hasText
                ? "This unloads the video and clears every text block. Your font, colors, background, and padding are kept."
                : "This unloads the video and returns to the drop screen."
        case .removeBlock:
            return "This removes the selected block, along with the text in it."
        }
    }

    var confirmTitle: String {
        switch action {
        case .clearVideo: return "Clear"
        case .removeBlock: return "Remove"
        }
    }
}
