import Foundation

/// Every way an export can fail, in one place—thrown from the exporter, the
/// renderer, and the FFmpeg runner alike.
enum ExportError: LocalizedError {
    case ffmpegNotFound
    case overlayRenderFailed
    case ffmpegFailed(status: Int32, detail: String)
    case wouldOverwriteSource
    case couldNotSaveOutput(String)
    case nothingToStamp

    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "FFmpeg was not found. Install it with \"brew install ffmpeg\", or bundle an ffmpeg binary with the app."
        case .overlayRenderFailed:
            return "The text overlay image could not be rendered."
        case .ffmpegFailed(let status, let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "FFmpeg exited with status \(status)."
                : "FFmpeg exited with status \(status): \(trimmed)"
        case .wouldOverwriteSource:
            return "The export destination matches the source video. Choose a different location."
        case .nothingToStamp:
            return "There is no story text to stamp onto the video."
        case .couldNotSaveOutput(let detail):
            return "The video encoded, but could not be saved to that location: \(detail)"
        }
    }

    /// Sentence-case title for the sheet that presents this failure. Only the
    /// missing binary earns its own: it is the one failure here that is about
    /// the machine rather than about this export.
    var failureTitle: String {
        switch self {
        case .ffmpegNotFound:
            return "FFmpeg Not Found"
        case .overlayRenderFailed, .ffmpegFailed, .wouldOverwriteSource, .couldNotSaveOutput, .nothingToStamp:
            return "Export Failed"
        }
    }
}
