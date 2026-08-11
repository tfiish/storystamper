# Developing Story Stamper

Purpose of this document: everything needed to build, test, and modify the app. The [README](README.md) covers what the app does; this covers how the code is organized and verified.

## Commands

| Task | Command |
| --- | --- |
| Debug build | `swift build` |
| Run the app | `swift run` |
| Release `.app` bundle | `./Scripts/make-app.sh` → `build/StoryStamper.app` |
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
│   │                            text, style, placement, and export lifecycle
│   ├── OverlayStyle.swift       Codable style settings + font/color/alignment enums
│   ├── VideoInfo.swift          One-shot AVFoundation probe (rotation-aware size)
│   └── SettingsStore.swift      UserDefaults persistence for style settings
├── Rendering/
│   └── OverlayRenderer.swift    Core Graphics text-block raster + placement math
├── Export/
│   ├── VideoExporter.swift      Temp PNG + FFmpeg argument construction
│   └── FFmpegService.swift      FFmpeg discovery, Process runner, progress parsing
└── Views/
    ├── ContentView.swift        Window layout, export sheet, error alert
    ├── VideoPreviewView.swift   Drop zone, preview canvas, drag, safe areas, transport
    ├── PlayerLayerView.swift    Bare AVPlayerLayer host (exact geometry, no chrome)
    ├── OverlayEditorView.swift  Right-hand controls panel
    └── ExportStatusView.swift   Progress, completion, and failure sheet
```

## Invariants worth preserving

- **Preview and export share pixels and math.** `OverlayRenderer.renderBlock` produces the one bitmap both display and export use; `clampedCenter` and `blockRect` are the only placement math. Change placement behavior in one place and both stay in sync.
- **Overlay position is normalized.** `StoryProject.overlayCenter` is in 0...1 video coordinates. Never store window-pixel positions.
- **User text never touches a shell or a filter string.** FFmpeg receives an argument array via `Process`, and the text itself only exists rasterized inside a PNG. Keep it that way when touching export code.
- **Rotation:** FFmpeg auto-rotates input before the filter graph, and the `sidedata=mode=delete:type=DISPLAYMATRIX` filter strips the stale rotation side data FFmpeg 7 would otherwise copy into the output. Removing that filter reintroduces a double-rotation bug on phone footage.
- **Font size and padding are in source-video pixels**, so identical settings produce identical exports regardless of window size.

## Style rules for this repo

- Oxford comma in any list, in code comments, UI copy, and docs alike.
- Em-dashes sit directly between words—like this—with no surrounding spaces.
- Comments only where behavior is non-obvious; no force unwraps.
