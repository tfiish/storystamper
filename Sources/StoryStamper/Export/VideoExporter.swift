import CoreGraphics
import Foundation

/// Orchestrates an export: renders the full-resolution overlay PNG, invokes
/// FFmpeg to composite and re-encode, and cleans up temporary files.
enum VideoExporter {
    static func export(
        videoInfo: VideoInfo,
        overlays: [PlacedOverlay],
        outputURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard outputURL.standardizedFileURL != videoInfo.url.standardizedFileURL else {
            throw ExportError.wouldOverwriteSource
        }
        guard let ffmpeg = FFmpegService.locateFFmpeg() else {
            throw ExportError.ffmpegNotFound
        }

        guard let canvas = OverlayRenderer.renderFullCanvas(
            overlays: overlays,
            videoSize: videoInfo.displaySize
        ) else {
            throw ExportError.overlayRenderFailed
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryStamper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let overlayURL = tempDirectory.appendingPathComponent("overlay.png")
        try OverlayRenderer.writePNG(canvas, to: overlayURL)

        let useHardware = FFmpegService.supportsVideoToolbox(executable: ffmpeg)
        try await FFmpegService.run(
            executable: ffmpeg,
            arguments: arguments(
                videoURL: videoInfo.url,
                overlayURL: overlayURL,
                outputURL: outputURL,
                useHardwareEncoder: useHardware,
                copyAudio: videoInfo.audioIsAAC
            ),
            durationSeconds: videoInfo.duration,
            onProgress: onProgress
        )
    }

    /// Builds the FFmpeg argument array. FFmpeg applies rotation metadata
    /// before filters run, so the overlay lands on the upright frame and
    /// portrait videos stay portrait. Because the pixels are now physically
    /// upright, the source's display-matrix side data must be deleted—FFmpeg 7
    /// otherwise carries it into the output, and players would rotate the
    /// frame a second time. The crop filter is a no-op for even dimensions and
    /// only exists so the encoder never rejects an odd size.
    private static func arguments(
        videoURL: URL,
        overlayURL: URL,
        outputURL: URL,
        useHardwareEncoder: Bool,
        copyAudio: Bool
    ) -> [String] {
        var args = [
            "-y",
            "-nostdin",
            "-i", videoURL.path,
            "-i", overlayURL.path,
            "-filter_complex",
            "[0:v][1:v]overlay=0:0:format=auto,crop=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p,sidedata=mode=delete:type=DISPLAYMATRIX[v]",
            "-map", "[v]",
            "-map", "0:a?",
        ]

        if useHardwareEncoder {
            // Apple's media engine, ~30x faster than libx264 on 4K. q:v is a
            // 0...100 constant-quality scale.
            args += ["-c:v", "h264_videotoolbox", "-q:v", "65"]
        } else {
            args += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20"]
        }

        args += copyAudio ? ["-c:a", "copy"] : ["-c:a", "aac", "-b:a", "192k"]

        args += [
            "-movflags", "+faststart",
            "-progress", "pipe:1",
            "-nostats",
            "-loglevel", "error",
            outputURL.path,
        ]
        return args
    }
}
