import Foundation

enum ExportError: LocalizedError {
    case ffmpegNotFound
    case overlayRenderFailed
    case ffmpegFailed(status: Int32, detail: String)
    case wouldOverwriteSource

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
        }
    }
}

/// Wraps a Process so it can cross into a @Sendable cancellation handler.
/// Process is thread-safe for terminate().
private final class ProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
}

/// Locates and runs FFmpeg. All invocations pass argument arrays directly to
/// Process—no shell is involved, so no escaping of user text is ever needed.
enum FFmpegService {
    /// Search order: a binary bundled in the app's Resources (for future
    /// standalone distribution), then common package-manager locations.
    static func locateFFmpeg() -> URL? {
        if let bundled = Bundle.main.url(forResource: "ffmpeg", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/local/bin/ffmpeg",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Runs FFmpeg, reporting progress as a 0...1 fraction parsed from the
    /// machine-readable `-progress` stream. Cancelling the surrounding Task
    /// terminates the process.
    static func run(
        executable: URL,
        arguments: [String],
        durationSeconds: Double?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        let box = ProcessBox(process)
        try await withTaskCancellationHandler {
            try process.run()

            // Collect stderr concurrently so a chatty process cannot deadlock
            // on a full pipe buffer.
            let stderrTask = Task.detached { () -> String in
                var data = Data()
                for try await byte in stderr.fileHandleForReading.bytes {
                    data.append(byte)
                }
                return String(data: data, encoding: .utf8) ?? ""
            }

            // FFmpeg's -progress stream emits key=value lines; out_time_us is
            // microseconds of output written so far.
            for try await line in stdout.fileHandleForReading.bytes.lines {
                guard let duration = durationSeconds, duration > 0 else { continue }
                for prefix in ["out_time_us=", "out_time_ms="] where line.hasPrefix(prefix) {
                    if let microseconds = Double(line.dropFirst(prefix.count)) {
                        onProgress(min(max(microseconds / 1_000_000 / duration, 0), 1))
                    }
                }
            }

            while process.isRunning {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            try Task.checkCancellation()

            let errorOutput = (try? await stderrTask.value) ?? ""
            guard process.terminationStatus == 0 else {
                throw ExportError.ffmpegFailed(
                    status: process.terminationStatus,
                    detail: String(errorOutput.suffix(2000))
                )
            }
        } onCancel: {
            if box.process.isRunning {
                box.process.terminate()
            }
        }
    }
}
