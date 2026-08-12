import CoreGraphics
import Foundation

/// Orchestrates an export: renders the full-resolution overlay PNG, invokes
/// FFmpeg to composite and re-encode, and cleans up temporary files.
///
/// FFmpeg encodes into the scratch directory, never straight to the
/// destination. The finished file is moved into place only after FFmpeg exits
/// cleanly, so a cancel, a failure, or a quit leaves nothing behind at the
/// location the user picked—the `defer` below sweeps the partial encode along
/// with the overlay.
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

        let session = try ExportScratch.makeSession()
        defer { try? FileManager.default.removeItem(at: session) }

        let overlayURL = session.appendingPathComponent("overlay.png")
        let stagedURL = session.appendingPathComponent("output.mp4")
        try OverlayRenderer.writePNG(canvas, to: overlayURL)

        let useHardware = FFmpegService.supportsVideoToolbox(executable: ffmpeg)
        try await FFmpegService.run(
            executable: ffmpeg,
            arguments: arguments(
                videoURL: videoInfo.url,
                overlayURL: overlayURL,
                outputURL: stagedURL,
                useHardwareEncoder: useHardware,
                hasAudio: videoInfo.hasAudio,
                copyAudio: videoInfo.audioIsAAC
            ),
            durationSeconds: videoInfo.duration,
            onProgress: onProgress
        )

        // Checked before the move as well as inside `run`, so a cancel landing
        // in the gap cannot promote a partial encode.
        try Task.checkCancellation()
        try install(stagedURL, at: outputURL)
    }

    /// Moves the finished encode into place. The save panel has already
    /// confirmed any overwrite, so replacing an existing file here is expected.
    private static func install(_ staged: URL, at destination: URL) throws {
        let manager = FileManager.default
        do {
            if manager.fileExists(atPath: destination.path) {
                try manager.removeItem(at: destination)
            }
            try manager.moveItem(at: staged, to: destination)
        } catch {
            throw ExportError.couldNotSaveOutput(error.localizedDescription)
        }
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
        hasAudio: Bool,
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
        ]

        if hasAudio {
            args += ["-map", "0:a?"]
        }

        if useHardwareEncoder {
            // Apple's media engine, ~30x faster than libx264 on 4K. q:v is a
            // 0...100 constant-quality scale.
            args += ["-c:v", "h264_videotoolbox", "-q:v", "65"]
        } else {
            args += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20"]
        }

        if hasAudio {
            args += copyAudio ? ["-c:a", "copy"] : ["-c:a", "aac", "-b:a", "192k"]
        } else {
            args += ["-an"]
        }

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
