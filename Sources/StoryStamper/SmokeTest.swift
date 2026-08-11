import CoreGraphics
import Foundation

/// Headless end-to-end export used during development:
///     StoryStamper --smoke-export input.mp4 output.mp4 ["story text"]
/// Exercises probe, render, and FFmpeg exactly as the UI does.
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

        Task.detached {
            do {
                let info = try await VideoInfo.probe(url: inputURL)
                print("probe: \(Int(info.displaySize.width))x\(Int(info.displaySize.height)), \(String(format: "%.2f", info.duration))s, \(info.nominalFrameRate) fps, audio: \(info.hasAudio)")

                guard let block = OverlayRenderer.renderBlock(text: text, style: OverlayStyle(), videoSize: info.displaySize) else {
                    fputs("SMOKE FAIL: overlay render returned nil\n", stderr)
                    exit(1)
                }
                print("overlay block: \(Int(block.pixelSize.width))x\(Int(block.pixelSize.height)) px")

                try await VideoExporter.export(
                    videoInfo: info,
                    block: block,
                    normalizedCenter: CGPoint(x: 0.5, y: 0.72),
                    outputURL: outputURL
                ) { progress in
                    print(String(format: "progress: %3.0f%%", progress * 100))
                }
                print("SMOKE OK: \(outputURL.path)")
                exit(0)
            } catch {
                fputs("SMOKE FAIL: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        dispatchMain()
    }
}
