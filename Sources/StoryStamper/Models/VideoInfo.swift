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

    enum ProbeError: LocalizedError {
        case noVideoTrack
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "The file does not contain a video track."
            case .unreadable(let detail):
                return "The video could not be opened: \(detail)"
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
