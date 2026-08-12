import Foundation

/// Something that went wrong, in the one shape the app shows failures in.
///
/// Loading and exporting both end here. They used to end in different places:
/// a probe error went to an alert, an export error went to a sheet as a bare
/// string, and only the sheet let you select the text—which was backwards,
/// since FFmpeg's messages are the ones worth pasting into a bug report.
struct StoryFailure: Identifiable, Equatable {
    let id = UUID()
    /// Sentence-case, and specific where being specific helps.
    let title: String
    /// The whole message, shown selectable.
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(loading error: VideoInfo.ProbeError) {
        self.init(
            title: error.failureTitle,
            message: error.errorDescription ?? "The video could not be opened."
        )
    }

    /// Takes any thrown error, because the export path can surface a file
    /// system error as readily as one of its own.
    init(exporting error: Error) {
        self.init(
            title: (error as? ExportError)?.failureTitle ?? "Export Failed",
            message: error.localizedDescription
        )
    }
}
