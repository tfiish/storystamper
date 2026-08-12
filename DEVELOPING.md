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
| Design-system check | `./Scripts/check-style.sh` |

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
│   ├── OverlayBlock.swift       One block: content, style, normalized center
│   ├── RenderedOverlay.swift    A rasterized block, and one placed for compositing
│   ├── VideoInfo.swift          One-shot AVFoundation probe (rotation-aware size)
│   ├── AppearanceChoice.swift   System, light, or dark, applied to NSApp
│   ├── ExportPhase.swift        Where an export is in its lifecycle
│   ├── ExportResolution.swift   Story frame or original quality, and the math
│   ├── StoryFailure.swift       Anything that went wrong, in one shape
│   └── InfoSheet.swift          Which of About or Settings is showing
├── State/
│   └── StoryProject.swift       @Observable source of truth: video, playback,
│                                text blocks (up to three), selection, and export
├── Support/
│   ├── SettingsStore.swift      UserDefaults persistence for preferences
│   ├── WindowCloseGuard.swift   Vetoes a window close, forwarding the rest
│   └── AppInfo.swift            Display name, version, and repository URL
├── Rendering/
│   └── OverlayRenderer.swift    Core Graphics text-block raster + placement math
├── Export/
│   ├── VideoExporter.swift      Overlay PNG, FFmpeg arguments, staged output
│   ├── FFmpegService.swift      FFmpeg discovery, Process runner, progress parsing
│   ├── ExportError.swift        Every way an export can fail
│   └── ExportScratch.swift      The one scratch root, swept at launch and quit
└── Views/
    ├── MainWindowView.swift     Three-column layout, the one sheet slot
    ├── StoryCommands.swift      The menu bar
    ├── SourceSidebarView.swift  Left: video, preview guides, theme, About, version
    ├── VideoPreviewView.swift   Center: preview canvas, drag, arrow keys, transport
    ├── PlayerLayerView.swift    Bare AVPlayerLayer host (exact geometry, no chrome)
    ├── StyleSidebarView.swift   Right: story text, text style, background, export
    ├── ExportStatusView.swift   Export progress and completion sheet
    ├── FailureSheet.swift       The one error presentation, selectable
    ├── SettingsView.swift       The preferences sheet
    ├── AboutView.swift          What the app is for, with a repository link
    └── Components/              Shared UI. Reach for one of these before writing
        ├── GlyphPicker.swift    Segmented glyph control: caption, focus, keys
        ├── SliderRow.swift      Labelled slider plus fixed-width readout
        ├── ColorRow.swift       Preset swatches plus the system color picker
        ├── IconButton.swift     Icon-only button; label is required, not optional
        ├── BarStrip.swift       Pinned bar-material strip (both footers, transport)
        ├── SidebarSplitter.swift  Draggable divider for the style sidebar
        ├── SheetChrome.swift    Title, padding, base font, and width for all four
        ├── HoverLabel.swift     The app's own tooltip; .help() is banned
        ├── FocusHaloModifier.swift  Keyboard-focus ring for self-drawn controls
        ├── Announcement.swift   Speaks a state change VoiceOver cannot infer
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
- **Destructive actions go through `requestClearVideo` and `requestRemoveSelectedBlock`.** Those are the only two paths that discard typed text, and the private half of each is where the undo step is registered. Calling `clearVideo` or `removeSelectedBlock` directly would throw text away with no way back, which is why both are private. There is no confirmation prompt any more: 1.8.2 decided that a warning and an undo stack are two answers to the same question, and kept the better one. Quitting still asks, because undo does not survive it.
- **Undo goes through `StoryProject`, not the views.** The window's undo manager arrives via `@Environment(\.undoManager)` in `MainWindowView`; everything else is registered inside the project, where the mutations are. A burst of same-kind edits on one block coalesces into a single step (`Motion.undoCoalesce`), so a slider drag is one Command-Z. Text is deliberately *not* registered—the text editor keeps its own undo, and two stacks over one field is worse than one.
- **There is one error type and one place it appears.** Loading and exporting both produce a `StoryFailure`, shown by `FailureSheet` with the message selectable. `ExportPhase` has no failure case for this reason. Adding a second presentation is how the alert-versus-sheet split happened the first time. The quit confirmation is an `NSAlert` and is not an exception to this—it asks a question rather than reporting a failure, and it has to answer synchronously; see *The one `NSAlert`* under Sheets.
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

Then tag it, and push the tag. GitHub's Releases page is built from tags, so a release that is only a commit does not appear there at all:

```bash
git tag -a 2.0.0 -m "Story Stamper 2.0.0"
```

```bash
git push origin main --follow-tags
```

The tag name is the bare version, no `v` prefix, matching `CFBundleShortVersionString` exactly—one string for the plist, the changelog heading, and the tag, so there is nothing to reconcile later. Annotated (`-a`) rather than lightweight, so the tag carries its own date and author. **Every version from 2.0.0 on gets one**; the releases before it predate the repository being public and have no tags to backfill.

## Design system

Every design value the interface draws with lives in [DesignSystem/DesignSystem.swift](Sources/StoryStamper/DesignSystem/DesignSystem.swift)—including color alpha, motion durations, stroke patterns, and named colors, not just geometry. Views contain no raw literals; if you need a value that is not there, add it there first.

That is enforced rather than remembered. `./Scripts/check-style.sh` reads every file under `Views/` and fails on a numeric literal inside a call the interface draws with, after a drawing argument label, or in a locally declared `CGFloat` or `Double`—and on a named color hue outside `Palette`. `make-app.sh` runs it before the release build, and it costs about 40 ms. The script's own header lists what it looks at, and the one thing it cannot see—a call split across lines, which is why the argument-label rule sits alongside the call rule.

| Token group | Values | Use |
| --- | --- | --- |
| `TextSize` | 10, 13, 16 | The only permitted text sizes |
| `Spacing` | 2, 4, 8, 12, 16, 24 | A 4-point grid for all gaps and insets |
| `Radius` | 6, 12 | Corner radii |
| `BorderWidth` | 1, 2, 3 | Strokes and hairlines |
| `Stroke` | named | Dash patterns |
| `Opacity` | named | Scrims, washes, rules, borders, rings, halos |
| `Palette` | named | Success and warning. Everything else is a system semantic |
| `Motion` | named | Animation and hover-delay durations |
| `FocusHalo` | named | The focus indicator for self-drawn controls |
| `IconSize` | 9, 12, 14, 16, 26, 34, 44 | Glyphs, including font specimens |
| `Interaction` | named | Snap tolerance and arrow-key steps |
| `Metrics` | named | Component sizes: sidebars, swatch, readout, sheets |
| `Instagram` | named | Where Instagram's UI covers a Story, and its text padding |

Use the `Font` helpers (`.appSmall`, `.appSmallDigits`, `.appRegular`, `.appRegularBold`, `.appTitle`) rather than SwiftUI's semantic styles, whose sizes fall off the scale (`.callout` is 12 pt, `.title3` is 15 pt).

Icon sizes are deliberately a separate scale from text: glyphs are balanced optically against their surroundings. A `.font(.system(size:))` on an `Image` is fine; on a `Text` it is not.

Two literals are allowed, and only two: `spacing: 0`, which means "no gap" structurally rather than picking a value off the scale, and `opacity(flag ? 1 : 0)`, which is fully on or fully off rather than an alpha. The checker knows about both, and about nothing else.

Color works the other way round from the numbers: reach for a system semantic first. `.primary`, `.secondary`, `.tertiary`, `.tint`, and `Color.accentColor` already track appearance, contrast settings, and the user's accent choice, and a named color cannot. `Palette` exists only for the two meanings no system semantic carries—success and warning. `Color.black` and `Color.white` are exempt from the checker because over video they are absolute colors rather than theme ones: a scrim is black because it is darkening pixels, not because the interface is in light mode.

The emphasis ramp is convention rather than token, because SwiftUI's hierarchical styles cannot be stored and passed around without losing what makes them work: `.primary` for content, `.secondary` for hints, captions, and readouts, `.tertiary` for text that should be findable but never read—which in practice is the version label alone.

## Sheets

Two shapes, deliberately. About and Settings are documents: fixed measure, left-aligned, a divider under the title. The export and failure sheets are outcomes: centered on an icon, sized to their content, because "Export Complete" and a 300-character FFmpeg error have no business being the same width.

Everything else about them is shared, and lives in [`SheetChrome.swift`](Sources/StoryStamper/Views/Components/SheetChrome.swift). Use `SheetTitle` for the heading and `.sheetChrome(width:)` for the frame; pass a width for a document, omit it for a status sheet. All four dismiss with a button reading **Done**.

### The one `NSAlert`, and why it stays

Quitting asks with an `NSAlert` ([StoryStamperApp.swift](Sources/StoryStamper/StoryStamperApp.swift)). It is the only one in the app, and it is deliberate rather than left over.

`windowShouldClose` is the only hook that can call off a close before AppKit performs it, and it has to answer `Bool` synchronously. A SwiftUI sheet cannot: presenting one returns immediately and the answer arrives later, by which point the window has gone. `NSAlert.runModal` runs its own modal loop and returns the answer, which is exactly the shape the hook needs. See [WindowCloseGuard.swift](Sources/StoryStamper/Support/WindowCloseGuard.swift) for why that hook and no other.

So the split is between two different questions, not two different opinions about presentation: **a failure is something the app is telling you, and it goes in a sheet; a quit is something the app is asking you before it stops existing, and it blocks.** The "one error, one place" invariant below is about failures, and it still holds without exception—no failure anywhere reaches an alert.

The alternative is to stop vetoing the close, let the window go, defer termination with `.terminateLater`, and drive a sheet on a window that is on its way out. That is materially more machinery on the quit path in exchange for typography, and rule zero is not on its side. Do not "fix" this without reading this paragraph first.

## Naming what the app does

One action, one name, wherever it is reached from—the control, the menu item, the panel title, and the undo step alike. The undo name is the one people forget, and it is the one that shows up in a different menu from the button that caused it.

| Action | Name |
| --- | --- |
| Load a video | **Open Video** when none is loaded, **Replace Video** when one is |
| Discard the video | **Unload Video** |
| Add a block | **Add Block** |
| Remove a block | **Remove Block** |
| Select one | **Select Block 1** |
| Export | **Export Video** |

**No trailing ellipses.** The platform convention would put one on every command that opens a panel, and five of this app's dozen commands do. A screen of trailing dots reads as noise rather than as a promise, so the convention is declined deliberately—not overlooked. An audit that rediscovers this should leave it alone.

The object is a **block**: Title Case in a control label or menu item, lowercase in a sentence. Not "text block"—the section is already called Story Text and the menu is already called Text, so the noun was carrying the word twice. Instagram's **Story** is capitalized, always.

Helper text earns its place or goes. A line that tells someone what they would find out by looking—that blocks snap to the midlines, that styling the selected block styles the selected block—is a line they read once and skip forever, and it pushes the controls down for everyone.

## Style rules for this repo

- Oxford comma in any list, in code comments, UI copy, and docs alike.
- Em-dashes sit directly between words—like this—with no surrounding spaces.
- Comments only where behavior is non-obvious; no force unwraps.
- Before writing a control, check `Views/Components`. A second copy of a slider row or an icon button is how the first drift starts.
- Run `./Scripts/check-style.sh` before opening a pull request, or build the app bundle, which runs it for you.
- Icon-only controls take a spoken label. `IconButton` and `GlyphPicker` both require one, so this is enforced rather than remembered.
- A control that draws itself is reachable by keyboard: focusable, a `focusHalo`, arrow keys, and an `accessibilityAdjustableAction` where it has a range. `GlyphPicker` and `SidebarSplitter` are the two worked examples.
- Anything a hover label says, the accessibility layer says too—as a label where it names the control, as a hint where it explains one. Hover labels themselves are for icon-only controls, which have no other way to say what they are; a control that already shows its own value does not get one.
