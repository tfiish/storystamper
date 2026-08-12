import Foundation

/// A destructive action waiting on the user's confirmation. The project holds
/// at most one of these at a time; presenting it is the only way any text is
/// thrown away while `confirmDestructiveActions` is on.
struct ConfirmationRequest: Identifiable, Equatable {
    enum Action: Equatable {
        case clearVideo
        case removeBlock
    }

    let id = UUID()
    let action: Action

    var title: String {
        switch action {
        case .clearVideo: return "Clear video and text?"
        case .removeBlock: return "Remove text block?"
        }
    }

    var message: String {
        switch action {
        case .clearVideo:
            return "This unloads the video and clears every text block. Your font, colors, background, and padding are kept."
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
