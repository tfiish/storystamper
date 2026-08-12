# Story Stamper

A single-purpose macOS utility: drop in a vertical video, type up to two short blocks of Instagram Story-style text, position them by dragging, and export a new MP4 with the text permanently burned into the pixels. Everything runs locally—no cloud, no accounts, no analytics.

## Requirements

- macOS 14 or later (Apple Silicon is the primary target)
- Xcode 16+ command line tools for building
- FFmpeg for exporting: `brew install ffmpeg`

The app looks for FFmpeg first inside its own Resources folder (for a future standalone build), then at `/opt/homebrew/bin`, `/usr/local/bin`, and `/opt/local/bin`. Preview and editing work without FFmpeg; only export requires it.

## Building and running

```bash
swift run
```

Or open the folder in Xcode (`open Package.swift`) and run the StoryStamper scheme. To produce a standalone app bundle at `build/StoryStamper.app`:

```bash
./Scripts/make-app.sh
```

Add `--install` to also copy it to `/Applications`, where it shows up in Finder, Spotlight, and Launchpad like any other app:

```bash
./Scripts/make-app.sh --install
```

The app icon is generated from [Scripts/make-icon.swift](Scripts/make-icon.swift) during the build, so there is no binary asset to maintain. If you place a standalone `ffmpeg` binary at `Support/ffmpeg` before running the script, it is bundled into the app so end users need no Homebrew installation.

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
- The `.app` bundle is ad-hoc signed, so first launch on another Mac requires right-click → Open.

## Project layout

See [DEVELOPING.md](DEVELOPING.md) for the file-by-file map, the headless smoke test, and release notes in [CHANGELOG.md](CHANGELOG.md).
