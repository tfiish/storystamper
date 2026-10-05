import Foundation

/// Which button Return presses on the Export Complete sheet.
///
/// Both close the sheet, and neither touches the exported file or the
/// original. Clear Video also empties the window, so the next clip can be
/// dropped straight in—worth a setting for anyone stamping a batch, and wrong
/// as a default for anyone who exports and then wants to tweak and export
/// again.
enum ExportCompletionAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case done
    case clearVideo

    var id: String { rawValue }

    /// The same words as the button it presses, so the setting and the sheet
    /// cannot disagree about what Return does.
    var displayName: String {
        switch self {
        case .done: return "Done"
        case .clearVideo: return "Clear Video"
        }
    }
}
