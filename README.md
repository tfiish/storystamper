# Story Stamper

A single-purpose macOS utility: drop in a vertical video, type up to two short blocks of Instagram Story-style text, position them by dragging, and export a new MP4 with the text permanently burned into the pixels.

There is no installer to download. You build it yourself from this source in about a minute, and it becomes a normal app in your Applications folder.

## Privacy

Story Stamper collects nothing, sends nothing, and needs no account. This is verifiable in the source, not just a promise:

- **No networking of any kind.** The app contains no HTTP client, no sockets, and no URLs. It imports only Apple's own frameworks—AppKit, SwiftUI, AVFoundation, Core Graphics, and Foundation—and has zero third-party dependencies ([Package.swift](Package.swift) declares none).
- **No analytics, telemetry, crash reporting, or update checks.**
- **Your video never leaves your Mac.** It is read from the location you choose, and the finished file is written where you tell it to go. Nothing else touches it.
- **The only things written outside your export** are your style preferences in `UserDefaults` (font, size, colors, background, padding, and alignment) and a single temporary PNG of the text overlay, which is deleted as soon as the export finishes.
- **Your story text is never saved to disk**, by design—it lives only in memory during the session.

The one external program involved is FFmpeg, which runs locally on your machine to encode the video. It is invoked directly as a subprocess with an argument list, never through a shell.

## Installing it on your Mac

**Prerequisites.** macOS 14 or later, and Xcode 16 or later (or just the Command Line Tools, which you can get with `xcode-select --install`). Export also needs FFmpeg, which is a one-time install via [Homebrew](https://brew.sh):

```bash
brew install ffmpeg
```

**Then clone and build.** Replace the URL with this repository's address:

```bash
git clone https://github.com/YOUR-USERNAME/storystamper.git
```

```bash
cd storystamper && ./Scripts/make-app.sh --install
```

That compiles a release build, assembles `StoryStamper.app`, generates its icon, signs it, and copies it to `/Applications`. When it finishes, Story Stamper is in Finder, Spotlight, and Launchpad like any other app—double-click it, or drag it to your Dock.

Because you compiled it yourself, macOS raises no Gatekeeper warning. (A `.app` copied from someone else's Mac would, since these builds are ad-hoc signed rather than notarized; the recipient would need to right-click → Open once.) Rerun the same command any time you change the code, and no Apple Developer account is required at any point.

## Developing

To run straight from source without installing, which is the fast loop while editing:

```bash
swift run
```

Or open the package in Xcode with `open Package.swift` and run the StoryStamper scheme. There is no `.xcodeproj`—Xcode reads the Swift package directly. `./Scripts/make-app.sh` without `--install` leaves the bundle in `build/` instead of `/Applications`.

The app icon is generated from [Scripts/make-icon.swift](Scripts/make-icon.swift) during the build, so there is no binary asset to maintain. The app looks for FFmpeg first inside its own Resources folder, then at `/opt/homebrew/bin`, `/usr/local/bin`, and `/opt/local/bin`; preview and editing work without FFmpeg, and only export requires it. If you place a standalone `ffmpeg` binary at `Support/ffmpeg` before building, it is bundled into the app so it needs no Homebrew installation at all.

## Using it

1. Drag an MP4, MOV, or M4V into the window, or click Choose Video.
2. Type into Story Text—the overlay updates live, preserving your line breaks and wrapping long lines automatically. Click Add Second Block for a second, independently styled overlay; the controls always edit the selected block, and a dashed ring marks the selection when two blocks exist.
3. Adjust font, size, alignment, color, background, and padding in the right-hand panel.
4. Drag either text block anywhere on the preview, or use the Top, Center, and Bottom quick-position buttons.
5. Optionally toggle the Story safe-area guides, which approximate where Instagram's UI covers a Story (they never appear in the export).
6. Click Export Story Video, choose a destination, and wait for the progress bar. The default filename appends `-story` so the source is never overwritten.

Presentation settings (font, size, colors, background, padding, and alignment) persist between launches. The text itself intentionally does not.

## How the renderer works

The core design goal is that the export matches the preview exactly, so both are fed by the same pixels:

1. **Core Graphics renders each text block once**—font, color, alignment, rounded background box, and drop shadow (when there is no box)—at full source-video resolution ([OverlayRenderer.swift](Sources/StoryStamper/Rendering/OverlayRenderer.swift)).
2. **The preview displays those same bitmaps**, scaled into the aspect-fit video rect. Each block's position is stored in normalized (0...1) video coordinates, so resizing the window never moves the exported text.
3. **On export**, every block is composited onto one transparent canvas at full video size, saved as a temporary PNG, and FFmpeg overlays it at (0, 0) for the whole duration ([VideoExporter.swift](Sources/StoryStamper/Export/VideoExporter.swift)).
4. Output is H.264 (libx264, CRF 18) plus AAC audio in an MP4 with `+faststart`. Dimensions, frame rate, and audio come straight from the source. Temporary files are deleted afterward.

Because the text never passes through a shell or an FFmpeg filter string—arguments go directly to `Process` as an array, and the text lives only inside a PNG—apostrophes, quotes, colons, percent signs, emoji, and multiline input are all safe.

Rotation is handled carefully: FFmpeg auto-rotates phone footage upright before compositing, and the exporter strips the source's display-matrix side data so players do not rotate the already-upright frame a second time.

## Known limitations

- At most two text blocks, each shown for the entire video—no animation, trimming, filters, or stickers, by design.
- Export requires an FFmpeg installation unless one is bundled into the app.
- The safe-area guides are reasonable approximations of Instagram's UI, not exact measurements.
- HDR sources are tone-mapped to 8-bit SDR output by the libx264 pipeline.
- The `.app` bundle is ad-hoc signed rather than notarized, so a build copied to another Mac needs right-click → Open the first time. Building it yourself avoids this entirely.
- The app is not sandboxed, because it launches FFmpeg and reads and writes files you pick anywhere on disk.

## Project layout

See [DEVELOPING.md](DEVELOPING.md) for the file-by-file map, the headless smoke test, and release notes in [CHANGELOG.md](CHANGELOG.md).
