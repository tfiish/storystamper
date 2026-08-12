import CoreGraphics
import Foundation

/// Headless end-to-end export used during development:
///     StoryStamper --smoke-export input.mp4 output.mp4 ["story text"]
/// Exercises probe, render, and FFmpeg exactly as the UI does.
///
/// Every phase is timed. Rule zero in DEVELOPING.md asks for a measurement
/// before any change that might cost speed, and this is where that number
/// comes from—"it only adds a few milliseconds" is not a measurement.
enum SmokeTest {
    static func run(arguments: [String]) {
        guard let flagIndex = arguments.firstIndex(of: "--smoke-export"),
              arguments.count > flagIndex + 2 else {
            fputs("Usage: StoryStamper --smoke-export input output [text]\n", stderr)
            exit(2)
        }
        let inputURL = URL(fileURLWithPath: arguments[flagIndex + 1])
        let outputURL = URL(fileURLWithPath: arguments[flagIndex + 2])
        let text = arguments.count > flagIndex + 3
            ? arguments[flagIndex + 3]
            : "Smoke test:\nIt's 100% \"working\"—émojis too 🎉"
        let resolution: ExportResolution = arguments.contains("--source-resolution") ? .source : .story

        Task.detached {
            let clock = ContinuousClock()
            let started = clock.now
            do {
                var mark = clock.now
                let info = try await VideoInfo.probe(url: inputURL)
                let audio = info.hasAudio ? (info.audioIsAAC ? "aac, copied" : "re-encoded") : "none"
                print("probe:    \(Int(info.displaySize.width))x\(Int(info.displaySize.height)), \(String(format: "%.2f", info.duration))s, \(info.nominalFrameRate) fps, audio: \(audio)  [\(elapsed(from: mark, clock: clock))]")

                let outputSize = resolution.outputSize(for: info.displaySize)
                print("output:   \(Int(outputSize.width))x\(Int(outputSize.height))  (\(resolution.displayName))")

                // A second, differently styled block exercises multi-block
                // compositing on every smoke run.
                var secondStyle = OverlayStyle()
                secondStyle.fontSize = 44
                secondStyle.backgroundEnabled = false
                let blocks = [
                    OverlayBlock(text: text, style: OverlayStyle(), center: CGPoint(x: 0.5, y: 0.72)),
                    OverlayBlock(text: "Second block ✓", style: secondStyle, center: CGPoint(x: 0.5, y: 0.18)),
                ]

                mark = clock.now
                guard let sample = OverlayRenderer.renderBlock(text: text, style: OverlayStyle(), videoSize: outputSize) else {
                    fputs("SMOKE FAIL: overlay render returned nil\n", stderr)
                    exit(1)
                }
                print("render:   \(Int(sample.pixelSize.width))x\(Int(sample.pixelSize.height)) px  [\(elapsed(from: mark, clock: clock))]")

                mark = clock.now
                try await VideoExporter.export(
                    videoInfo: info,
                    blocks: blocks,
                    resolution: resolution,
                    outputURL: outputURL
                ) { progress in
                    print(String(format: "progress: %3.0f%%", progress * 100))
                }
                print("export:   [\(elapsed(from: mark, clock: clock))]")
                print("SMOKE OK: \(outputURL.path)  [total \(elapsed(from: started, clock: clock))]")
                exit(0)
            } catch {
                fputs("SMOKE FAIL: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        dispatchMain()
    }

    private static func elapsed(from mark: ContinuousClock.Instant, clock: ContinuousClock) -> String {
        let seconds = Double((clock.now - mark).components.attoseconds) / 1e18
            + Double((clock.now - mark).components.seconds)
        return String(format: "%.2fs", seconds)
    }
}
