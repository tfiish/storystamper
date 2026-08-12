# Developing Story Stamper

Purpose of this document: everything needed to build, test, and modify the app. The [README](README.md) covers what the app does; this covers how the code is organized and verified.

## Rule zero: this app is lightweight

**Story Stamper's single most important property is that it is fast.** Fast to open, fast to type a caption into, fast to export. That is the entire reason it exists—the workflow it replaces is moving a clip onto a phone and back, and any version of this app that feels heavy is not worth using instead.

**If a change would substantially slow down launch, editing, or export, it should not be implemented.** Not behind a setting, not "just for power users", not with a loading spinner to cover it. Reject it. This outranks every other consideration in this document, including consistency, completeness, and features that would be nice to have.

Concretely, this rules out:

- Third-party dependencies. [Package.swift](Package.swift) declares none, and that is a feature. Every one of them is startup time and binary size.
- Anything on the network: no accounts, telemetry, crash reporting, update checks, or cloud anything. Launch must never wait on a server.
- Work at launch that is not needed to show the window and accept a drop.
- Per-keystroke or per-frame work that grows with video resolution. The overlay render cache exists precisely because rasterizing text at 4K on every keystroke was too slow.
- Scope that turns a single-purpose utility into an editor: timelines, trimming, filters, animation, stickers, or more than three text blocks.

Speed you have already paid for and must not give back: hardware H.264 encoding, audio remuxing instead of re-encoding, the signature-cached overlay renders, and live progress parsing. Each is called out under *Invariants worth preserving* below.

When a change is a genuine trade—slower but meaningfully better—measure it first and say so in the pull request. "It only adds a few milliseconds" is not a measurement.

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
├── StoryStamperApp.swift        Entry point, app delegate, quit guard; routes
│                                --smoke-export to SmokeTest
├── SmokeTest.swift              Headless end-to-end export
├── DesignSystem/
│   └── DesignSystem.swift       Every number the interface draws with
├── Models/                      Value types. No behavior beyond their own data.
│   ├── OverlayStyle.swift       Codable style settings + font/color/alignment enums
│   ├── OverlayBlock.swift       One text block: content, style, normalized center
│   ├── RenderedOverlay.swift    A rasterized block, and one placed for compositing
│   ├── VideoInfo.swift          One-shot AVFoundation probe (rotation-aware size)
│   ├── AppearanceChoice.swift   System, light, or dark, applied to NSApp
│   ├── ExportPhase.swift        Where an export is in its lifecycle
│   ├── ConfirmationRequest.swift  A destructive action awaiting confirmation
│   └── InfoSheet.swift          Which of About or Settings is showing
├── State/
│   └── StoryProject.swift       @Observable source of truth: video, playback,
│                                text blocks (up to three), selection, and export
├── Support/
│   ├── SettingsStore.swift      UserDefaults persistence for preferences
│   └── AppInfo.swift            Display name, version, and repository URL
├── Rendering/
│   └── OverlayRenderer.swift    Core Graphics text-block raster + placement math
├── Export/
│   ├── VideoExporter.swift      Overlay PNG, FFmpeg arguments, staged output
│   ├── FFmpegService.swift      FFmpeg discovery, Process runner, progress parsing
│   ├── ExportError.swift        Every way an export can fail
│   └── ExportScratch.swift      The one scratch root, swept at launch and quit
└── Views/
    ├── MainWindowView.swift     Three-column layout, export sheet, error alert
    ├── StoryCommands.swift      The menu bar
    ├── SourceSidebarView.swift  Left: video, preview guides, theme, About, version
    ├── VideoPreviewView.swift   Center: preview canvas, drag, arrow keys, transport
    ├── PlayerLayerView.swift    Bare AVPlayerLayer host (exact geometry, no chrome)
    ├── StyleSidebarView.swift   Right: story text, text style, background, export
    ├── ExportStatusView.swift   Progress, completion, and failure sheet
    ├── ConfirmationSheet.swift  Destructive confirmation, with "Don't ask again"
    ├── SettingsView.swift       The preferences sheet
    ├── AboutView.swift          What the app is for, with a repository link
    └── Components/              Shared UI. Reach for one of these before writing
        ├── GlyphPicker.swift    Segmented glyph control: fast tooltip, focus, keys
        ├── SliderRow.swift      Labelled slider plus fixed-width readout
        ├── ColorRow.swift       Preset swatches plus the system color picker
        ├── IconButton.swift     Icon-only button; label is required, not optional
        ├── BarStrip.swift       Pinned bar-material strip (both footers, transport)
        ├── SidebarSplitter.swift  Draggable divider for the style sidebar
        └── FontSample.swift     Font specimens rasterized in their own typefaces
```

## Invariants worth preserving

- **Preview and export share code and math, not bitmaps.** Both go through `OverlayRenderer.renderBlock`, and `clampedCenter` and `blockRect` are the only placement math. The preview rasterizes at the source's resolution; the exporter rasterizes again at the *output* resolution, so text is drawn once at the size it will be seen at rather than drawn large and resampled. They still agree because style sizes are authored against a 1080-wide frame and scaled by the narrow side, and scaling preserves aspect—so a block occupies the same fraction of the frame at any resolution. Change that scaling rule and you break the match.
- **Export never reads the preview's render cache.** `canExport` asks whether there is text, not whether a bitmap has finished drawing, and `VideoExporter` takes `[OverlayBlock]` and renders its own. This is what lets preview rendering be asynchronous without an export ever catching a stale or half-drawn overlay.
- **Overlay rasterization happens off the main actor, coalesced.** Typing a caption and dragging a slider both invalidate the render, and on 4K footage a render is a bitmap thousands of pixels wide. `StoryProject.scheduleRender` keeps one in-flight task per block and holds the previous bitmap until the new one lands. Do not make this synchronous again.
- **Scratch is never swept on the critical path.** Quitting renames the scratch root (`ExportScratch.discard`, constant time); the next launch deletes it in the background (`sweep`). A killed 4K export can leave gigabytes there, and deleting that at launch or quit is exactly the stall rule zero forbids.
- **Overlay positions are normalized.** Each `OverlayBlock.center` is in 0...1 video coordinates. Never store window-pixel positions.
- **Blocks are capped at three** (`StoryProject.maxBlocks`) and require a loaded video, and re-rendering is signature-cached per block—dragging never re-rasterizes text, only text, style, or video changes do.
- **User text never touches a shell or a filter string.** FFmpeg receives an argument array via `Process`, and the text itself only exists rasterized inside a PNG. Keep it that way when touching export code.
- **Rotation:** FFmpeg auto-rotates input before the filter graph, and the `sidedata=mode=delete:type=DISPLAYMATRIX` filter strips the stale rotation side data FFmpeg 7 would otherwise copy into the output. Removing that filter reintroduces a double-rotation bug on phone footage.
- **Font size and padding are authored against a 1080-wide frame** and multiplied by `min(width, height) / 1080` in `OverlayRenderer.scaled(_:for:)`. Window size never affects them; video resolution scales them proportionally so a setting looks the same on 1080p and 4K.
- **Exports default to the Story frame.** `ExportResolution.story` fits the narrow side to 1080 and never upscales. On the 4K fixture this is 40 MB in 16 s against 99 MB in 21 s, for a destination that serves 1080 × 1920 either way. `.source` remains available in Settings.
- **Export prefers `h264_videotoolbox`.** `FFmpegService.supportsVideoToolbox` probes `ffmpeg -encoders` per export (about 30 ms) and `VideoExporter` falls back to libx264 `veryfast` when it is missing. On a 38-second 4K clip this is the difference between roughly 20 seconds and over ten minutes, so do not "simplify" it back to a single software encoder.
- **Nothing is written to the user's chosen destination until the encode succeeds.** FFmpeg writes into `ExportScratch`, and `VideoExporter.install` moves the finished file into place. A cancel, a failure, or a quit therefore leaves no truncated MP4 behind. Do not "simplify" this by pointing FFmpeg at the destination.
- **Destructive actions go through `requestClearVideo` and `requestRemoveSelectedBlock`.** Those are the only two paths that discard typed text, and they are where the confirmation lives. Calling `clearVideo` or `removeSelectedBlock` directly would bypass it, which is why both are private.
- **Progress is read with `readabilityHandler`, not `FileHandle.bytes`.** The async byte sequence buffers so aggressively that progress arrived in one late lump; the handler-based reader delivers FFmpeg's twice-a-second updates live.

## Measuring

Rule zero asks for a measurement before any change that might cost speed. The smoke test times each phase, so the before-and-after is one command:

```bash
.build/debug/StoryStamper --smoke-export TestMedia/squeezy.MOV /tmp/out.mp4 | grep -v progress
```

```
probe:    2160x3840, 38.48s, 30.0 fps, audio: aac, copied  [0.02s]
output:   1080x1920  (Story (1080))
render:   818x323 px  [0.07s]
export:   [16.19s]
SMOKE OK: /tmp/out.mp4  [total 16.27s]
```

Pass `--source-resolution` to compare against a full-resolution encode. Use a release build (`swift build -c release`) for any number you intend to quote; the debug build is not representative.

For launch time, which the smoke test cannot cover, quit the app first and time a cold start by hand. Anything you can perceive is too slow.

## Releasing

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, and keep `AppInfo.developmentVersion` in step—the sidebar footer reads the bundle when installed and falls back to that constant under `swift run`. Add a `CHANGELOG.md` entry, then `./Scripts/make-app.sh --install`.

## Design system

Every number the interface draws with lives in [DesignSystem/DesignSystem.swift](Sources/StoryStamper/DesignSystem/DesignSystem.swift)—including color alpha, motion durations, and stroke patterns, not just geometry. Views should contain no raw layout literals; if you need a value that is not there, add it there first.

| Token group | Values | Use |
| --- | --- | --- |
| `TextSize` | 10, 13, 16 | The only permitted text sizes |
| `Spacing` | 2, 4, 8, 12, 16, 24 | A 4-point grid for all gaps and insets |
| `Radius` | 6, 12 | Corner radii |
| `BorderWidth` | 1, 2, 3 | Strokes and hairlines |
| `Stroke` | named | Dash patterns |
| `Opacity` | named | Scrims, washes, rules, borders, rings, halos |
| `Motion` | named | Animation and hover-delay durations |
| `FocusHalo` | named | The focus indicator for self-drawn controls |
| `IconSize` | 9, 12, 14, 16, 26, 34, 44 | Glyphs, including font specimens |
| `Interaction` | named | Snap tolerance and arrow-key steps |
| `Metrics` | named | Component sizes: sidebars, swatch, readout, sheets |

Use the `Font` helpers (`.appSmall`, `.appSmallDigits`, `.appRegular`, `.appRegularBold`, `.appTitle`) rather than SwiftUI's semantic styles, whose sizes fall off the scale (`.callout` is 12 pt, `.title3` is 15 pt).

Icon sizes are deliberately a separate scale from text: glyphs are balanced optically against their surroundings. A `.font(.system(size:))` on an `Image` is fine; on a `Text` it is not.

The one allowed literal is `spacing: 0`, which means "no gap" structurally rather than picking a value off the scale.

## Style rules for this repo

- Oxford comma in any list, in code comments, UI copy, and docs alike.
- Em-dashes sit directly between words—like this—with no surrounding spaces.
- Comments only where behavior is non-obvious; no force unwraps.
- Before writing a control, check `Views/Components`. A second copy of a slider row or an icon button is how the first drift starts.
- Icon-only controls take a spoken label. `IconButton` and `GlyphPicker` both require one, so this is enforced rather than remembered.
