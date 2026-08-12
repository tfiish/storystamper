# Developing Story Stamper

Purpose of this document: everything needed to build, test, and modify the app. The [README](README.md) covers what the app does; this covers how the code is organized and verified.

## Commands

| Task | Command |
| --- | --- |
| Debug build | `swift build` |
| Run the app | `swift run` |
| Release `.app` bundle | `./Scripts/make-app.sh` → `build/StoryStamper.app` |
| Build and install to /Applications | `./Scripts/make-app.sh --install` |
| Regenerate the icon alone | `swift Scripts/make-icon.swift out.iconset` |
| Headless export test | `.build/debug/StoryStamper --smoke-export in.mp4 out.mp4 ["text"]` |

There is no separate test target; the smoke test exercises the full probe → render → export pipeline (the same code paths the UI calls) without launching a window. If no text argument is given, it uses a string full of hostile characters—apostrophes, quotes, a percent sign, an em-dash, accents, and an emoji.

Generating disposable test fixtures:

```bash
# Plain portrait video with audio
ffmpeg -f lavfi -i "testsrc2=size=1080x1920:rate=30:duration=4" \
       -f lavfi -i "sine=frequency=440:duration=4" \
       -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest portrait.mp4

# Phone-style rotated video (stored landscape, 90° display matrix)
ffmpeg -f lavfi -i "testsrc2=size=1920x1080:rate=30:duration=3" \
       -c:v libx264 -pix_fmt yuv420p landscape.mp4
ffmpeg -display_rotation 90 -i landscape.mp4 -c copy rotated.mov
```

After exporting the rotated fixture, verify the output has upright dimensions and **no** `rotation` side data:

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -show_entries stream_side_data=rotation -of default=noprint_wrappers=1 out.mp4
```

## Architecture map

```
Sources/StoryStamper/
├── StoryStamperApp.swift        Entry point; routes --smoke-export to SmokeTest
├── SmokeTest.swift              Headless end-to-end export
├── Models/
│   ├── StoryProject.swift       @Observable source of truth: video, playback,
│   │                            text blocks (up to two), selection, and export
│   ├── OverlayStyle.swift       Codable style settings + font/color/alignment enums
│   ├── VideoInfo.swift          One-shot AVFoundation probe (rotation-aware size)
│   ├── SettingsStore.swift      UserDefaults persistence for style settings
│   └── AppInfo.swift            Display name and version for the sidebar footer
├── Rendering/
│   └── OverlayRenderer.swift    Core Graphics text-block raster + placement math
├── Export/
│   ├── VideoExporter.swift      Temp PNG + FFmpeg argument construction
│   └── FFmpegService.swift      FFmpeg discovery, Process runner, progress parsing
└── Views/
    ├── ContentView.swift        Three-column layout, export sheet, error alert
    ├── SourceSidebarView.swift  Left: video info, preview guides, About, version
    ├── VideoPreviewView.swift   Center: preview canvas, drag, safe areas, transport
    ├── PlayerLayerView.swift    Bare AVPlayerLayer host (exact geometry, no chrome)
    ├── StyleSidebarView.swift   Right: story text, text style, text background, export
    └── ExportStatusView.swift   Progress, completion, and failure sheet
```

## Invariants worth preserving

- **Preview and export share pixels and math.** `OverlayRenderer.renderBlock` produces the one bitmap per block that both display and export use; `clampedCenter` and `blockRect` are the only placement math. Change placement behavior in one place and both stay in sync.
- **Overlay positions are normalized.** Each `OverlayBlock.center` is in 0...1 video coordinates. Never store window-pixel positions.
- **Blocks are capped at two** (`StoryProject.maxBlocks`), and re-rendering is signature-cached per block—dragging never re-rasterizes text, only text, style, or video changes do.
- **User text never touches a shell or a filter string.** FFmpeg receives an argument array via `Process`, and the text itself only exists rasterized inside a PNG. Keep it that way when touching export code.
- **Rotation:** FFmpeg auto-rotates input before the filter graph, and the `sidedata=mode=delete:type=DISPLAYMATRIX` filter strips the stale rotation side data FFmpeg 7 would otherwise copy into the output. Removing that filter reintroduces a double-rotation bug on phone footage.
- **Font size and padding are authored against a 1080-wide frame** and multiplied by `min(width, height) / 1080` in `OverlayRenderer.scaled(_:for:)`. Window size never affects them; video resolution scales them proportionally so a setting looks the same on 1080p and 4K.
- **Export prefers `h264_videotoolbox`.** `FFmpegService.supportsVideoToolbox` probes `ffmpeg -encoders` per export (about 30 ms) and `VideoExporter` falls back to libx264 `veryfast` when it is missing. On a 38-second 4K clip this is the difference between roughly 20 seconds and over ten minutes, so do not "simplify" it back to a single software encoder.
- **Progress is read with `readabilityHandler`, not `FileHandle.bytes`.** The async byte sequence buffers so aggressively that progress arrived in one late lump; the handler-based reader delivers FFmpeg's twice-a-second updates live.

## Releasing

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, and keep `AppInfo.developmentVersion` in step—the sidebar footer reads the bundle when installed and falls back to that constant under `swift run`. Add a `CHANGELOG.md` entry, then `./Scripts/make-app.sh --install`.

## Typography

Text uses exactly five sizes, defined in `Views/Typography.swift`: **8, 10, 13, 16, and 21 pt**. Nothing else is permitted. Use the `Font` helpers (`.appSmall`, `.appSmallDigits`, `.appRegular`, `.appRegularBold`, `.appTitle`) rather than SwiftUI's semantic styles, whose sizes fall off the scale (`.callout` is 12, `.title3` is 15).

SF Symbol and icon sizes are chosen optically and are deliberately outside this scale; a `.font(.system(size:))` on an `Image` is fine, on a `Text` it is not.

## Style rules for this repo

- Oxford comma in any list, in code comments, UI copy, and docs alike.
- Em-dashes sit directly between words—like this—with no surrounding spaces.
- Comments only where behavior is non-obvious; no force unwraps.
