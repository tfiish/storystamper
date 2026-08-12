import AVFoundation
import AudioToolbox
import Foundation

/// Metadata about a source video, probed once at load time.
/// `displaySize` has the track's preferredTransform applied, so a portrait
/// phone recording reports 1080×1920 even when stored as rotated 1920×1080.
struct VideoInfo: Sendable {
    let url: URL
    let displaySize: CGSize
    let duration: Double
    let nominalFrameRate: Float
    let hasAudio: Bool
    /// When true the audio can be remuxed into the MP4 untouched, which is
    /// both faster and avoids a generation of re-encoding loss.
    let audioIsAAC: Bool

    var filename: String { url.lastPathComponent }
    var durationText: String { Self.timecode(duration) }
    var dimensionsText: String { Self.dimensions(displaySize) }
    var frameRateText: String? { Self.frameRate(nominalFrameRate) }

    /// The one place a frame size is formatted, for the same reason as
    /// `timecode`: the sidebar, the Settings copy, and the smoke test were
    /// each building this string by hand, and had already drifted apart on
    /// which character sits between the numbers.
    ///
    /// The separator is a parameter only so the command line can use an ASCII
    /// `x`, which is a terminal convention rather than a different opinion.
    static func dimensions(_ size: CGSize, separator: String = " × ") -> String {
        "\(Int(size.width))\(separator)\(Int(size.height))"
    }

    /// Nil when the track reports no usable rate, so callers omit the field
    /// rather than printing a zero. `%.5g` drops trailing zeros, so 30 reads
    /// as "30" while 29.97 keeps its precision—the sidebar showed the former
    /// and the smoke test the latter for the very same file.
    static func frameRate(_ rate: Float) -> String? {
        guard rate > 0 else { return nil }
        return String(format: "%.5g", rate)
    }

    /// The one place playback time is formatted, so the sidebar and the
    /// transport bar can never disagree about what 90 seconds looks like.
    static func timecode(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    enum ProbeError: LocalizedError {
        case noVideoTrack
        case unreadable(String)
        case unsupportedType

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "The file does not contain a video track."
            case .unreadable(let detail):
                return "The video could not be opened: \(detail)"
            case .unsupportedType:
                return "Please choose an MP4, MOV, or M4V video."
            }
        }

        /// Title Case title for the sheet that presents this failure.
        var failureTitle: String {
            switch self {
            case .unsupportedType:
                return "Unsupported File Type"
            case .noVideoTrack, .unreadable:
                return "Could Not Load Video"
            }
        }
    }

    static func probe(url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        let videoTracks: [AVAssetTrack]
        do {
            videoTracks = try await asset.loadTracks(withMediaType: .video)
        } catch {
            throw ProbeError.unreadable(error.localizedDescription)
        }
        guard let track = videoTracks.first else {
            throw ProbeError.noVideoTrack
        }

        let (naturalSize, transform, frameRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let duration = try await asset.load(.duration)
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []

        // Apply the rotation transform so we work in upright display coordinates.
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        guard displaySize.width > 0, displaySize.height > 0 else {
            throw ProbeError.unreadable("The video reports invalid dimensions.")
        }

        var audioIsAAC = false
        if let audioTrack = audioTracks.first,
           let descriptions = try? await audioTrack.load(.formatDescriptions) {
            audioIsAAC = descriptions.contains {
                CMFormatDescriptionGetMediaSubType($0) == kAudioFormatMPEG4AAC
            }
        }

        return VideoInfo(
            url: url,
            displaySize: displaySize,
            duration: duration.seconds,
            nominalFrameRate: frameRate,
            hasAudio: !audioTracks.isEmpty,
            audioIsAAC: audioIsAAC
        )
    }
}
