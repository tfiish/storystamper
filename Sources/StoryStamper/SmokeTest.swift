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

                guard let mainBlock = OverlayRenderer.renderBlock(text: text, style: OverlayStyle(), videoSize: info.displaySize) else {
                    fputs("SMOKE FAIL: overlay render returned nil\n", stderr)
                    exit(1)
                }
                print("overlay block: \(Int(mainBlock.pixelSize.width))x\(Int(mainBlock.pixelSize.height)) px")

                // A second, differently styled block exercises multi-block
                // compositing on every smoke run.
                var secondStyle = OverlayStyle()
                secondStyle.fontSize = 44
                secondStyle.backgroundMode = .none
                var overlays = [PlacedOverlay(overlay: mainBlock, center: CGPoint(x: 0.5, y: 0.72))]
                if let second = OverlayRenderer.renderBlock(text: "Second block ✓", style: secondStyle, videoSize: info.displaySize) {
                    overlays.append(PlacedOverlay(overlay: second, center: CGPoint(x: 0.5, y: 0.18)))
                }

                try await VideoExporter.export(
                    videoInfo: info,
                    overlays: overlays,
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
