import Foundation

enum ExportError: LocalizedError {
    case ffmpegNotFound
    case overlayRenderFailed
    case ffmpegFailed(status: Int32, detail: String)
    case wouldOverwriteSource
    case couldNotSaveOutput(String)

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
        case .couldNotSaveOutput(let detail):
            return "The video encoded, but could not be saved to that location: \(detail)"
        }
    }
}

/// Wraps a Process so it can cross into a @Sendable cancellation handler.
/// Process is thread-safe for terminate().
private final class ProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
}

/// Splits pipe data into lines. Pipe handlers fire on a background queue, so
/// the buffer is lock-protected.
private final class LineAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ data: Data, onLine: (String) -> Void) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let slice = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let line = String(data: slice, encoding: .utf8) {
                lines.append(line)
            }
        }
        lock.unlock()
        // Deliver outside the lock so callers can do real work.
        for line in lines { onLine(line) }
    }
}

private final class DataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
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

    /// Whether this FFmpeg build offers Apple's hardware H.264 encoder, which
    /// is roughly thirty times faster than libx264 on 4K footage. Costs about
    /// 30 ms to check, which is nothing next to an export.
    static func supportsVideoToolbox(executable: URL) -> Bool {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-hide_banner", "-encoders"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.contains("h264_videotoolbox") ?? false
    }

    /// Runs FFmpeg, reporting progress as a 0...1 fraction parsed from the
    /// machine-readable `-progress` stream, which emits roughly twice a
    /// second. Cancelling the surrounding Task terminates the process.
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

        let accumulator = LineAccumulator()
        let errorOutput = DataCollector()

        // readabilityHandler delivers data as FFmpeg writes it. (FileHandle's
        // async `bytes` sequence buffers far too aggressively here, which is
        // why progress used to arrive in one late lump.)
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            accumulator.append(chunk) { line in
                guard let duration = durationSeconds, duration > 0 else { return }
                // out_time_ms is misnamed upstream: both keys are microseconds.
                for prefix in ["out_time_us=", "out_time_ms="] where line.hasPrefix(prefix) {
                    if let microseconds = Double(line.dropFirst(prefix.count)) {
                        onProgress(min(max(microseconds / 1_000_000 / duration, 0), 1))
                    }
                }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            errorOutput.append(chunk)
        }

        let box = ProcessBox(process)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    // Pick up anything buffered between the last handler call
                    // and exit, so failures always carry their message.
                    errorOutput.append(stderr.fileHandleForReading.readDataToEndOfFile())
                    continuation.resume()
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }

            try Task.checkCancellation()
            guard process.terminationStatus == 0 else {
                throw ExportError.ffmpegFailed(
                    status: process.terminationStatus,
                    detail: String(errorOutput.string.suffix(2000))
                )
            }
        } onCancel: {
            if box.process.isRunning {
                box.process.terminate()
            }
        }
    }
}
