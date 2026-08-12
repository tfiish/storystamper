# Story Stamper

A single-purpose macOS utility: drop in a vertical video, type up to three short blocks of Instagram Story-style text, position them by dragging, and export a new MP4 with the text permanently burned into the pixels.

## What it's for

Story Stamper exists for one workflow: stamping a video with text before you schedule it to your Instagram story from Meta Business Suite. Scheduling tools let you upload a video, but not add Story-style text to it, so the usual workaround is to move the clip onto a phone, add text in the Instagram app, save it back, and pull it off again. This skips all of that. It adds text, and only text—no trimming, no filters, no stickers. It is extremely lightweight, and intentionally feature-poor, to allow you to quickly process a batch of videos in this one specific way.

## How you're meant to use it

This is not a downloadable installer, and it is not a command-line tool. You clone this repository and run one command, which compiles a real, self-contained `StoryStamper.app` into your Applications folder. From that point on you use it like any other Mac app: open it from Spotlight, the Dock, or Finder, and drag videos onto it. **You never need to touch the terminal again** (unless you want to update the app from GitHub).

## Privacy

Story Stamper collects nothing, sends nothing, and needs no account. This is verifiable in the source, not just a promise:

- **No networking of any kind.** The app contains no HTTP client and no sockets, and never makes a request. The only URL anywhere in it is the link to this repository in the About box, which opens in your browser if you click it. It imports only Apple's own frameworks—AppKit, SwiftUI, AVFoundation, Core Graphics, and Foundation—and has zero third-party dependencies ([Package.swift](Package.swift) declares none).
- **No analytics, telemetry, crash reporting, or update checks.**
- **Your video never leaves your Mac.** It is read from the location you choose, and the finished file is written where you tell it to go. Nothing else touches it.
- **The only things written outside your export** are your preferences in `UserDefaults` (font, size, colors, background, padding, alignment, appearance, sidebar width, and export size) and, during an export, a temporary folder holding the overlay PNG and the in-progress encode. That folder is deleted when the export finishes; quitting moves anything left aside instantly, and the next launch clears it in the background, so a crash cannot leave anything behind.
- **Your story text is never saved to disk**, by design—it lives only in memory during the session.

The one external program involved is FFmpeg, which runs locally on your machine to encode the video. It is invoked directly as a subprocess with an argument list, never through a shell.

## Installing it on your Mac

**Prerequisites.** macOS 14 or later, and Xcode 16 or later (or just the Command Line Tools, which you can get with `xcode-select --install`). Export also needs FFmpeg, which is a one-time install via [Homebrew](https://brew.sh):

```bash
brew install ffmpeg
```

**Then clone and build:**

```bash
git clone https://github.com/tfiish/storystamper.git
```

```bash
cd storystamper && ./Scripts/make-app.sh --install
```

That compiles a release build, assembles `StoryStamper.app`, generates its icon, signs it, and copies it to `/Applications`. When it finishes, Story Stamper is in Finder, Spotlight, and Launchpad like any other app—double-click it, or drag it to your Dock.

Because you compiled it yourself, macOS raises no Gatekeeper warning. (A `.app` copied from someone else's Mac would, since these builds are ad-hoc signed rather than notarized; the recipient would need to right-click → Open once.) Rerun the same command any time you change the code, and no Apple Developer account is required at any point.

(If you are not a developer, simply paste this entire README into the AI agent of your choice and ask it to walk you through these simple setup steps.)

## Using it

1. Browse for your MP4, MOV, or M4V—or drag it into the window.
2. Type your desired text in up to three independently styled text blocks. The video overlay updates live, preserving your line breaks and wrapping long lines automatically.
3. Adjust font, size, alignment, color, background, and padding for each text block.
4. Drag any text block where you want it on the preview, or select it and use the arrow keys (Shift + arrow moves it in larger steps). Dragging near the horizontal or vertical midline snaps to the guideline that appears.
5. Click Clear Video in the left panel to start over. The story text will clear along with the video, but your styling will carry over to the next clip. It does **not** ask first—but Command-Z puts the video and the text back (as it does for adding or removing a block, restyling one, and moving one).
6. Click Export Video, choose a destination, and wait for the progress bar. Even a large (100+ MB) video file should process in under 30 seconds. The default filename appends `-story` so the source video is never overwritten. Nothing is written to that destination until the encode finishes, so a canceled or failed export leaves no half-written file behind. By default, exports are sized to a 1080-wide Story frame but you can export at the original resolution from the Settings menu.

The style sidebar on the right can be resized by dragging the divider beside it. This setting, along with your theme and your text presentation settings (font, size, colors, background, padding, and alignment), persist between launches. Videos, text, and undo history do not.

Everything above is also in the menu bar, with shortcuts: Command-O to open or replace, Command-E to export, Command-Shift-N to add a block, Command-Shift-Delete to remove one, Command-1 through Command-3 to select one, Command-Shift-A for the guides, and Command-Z to undo. Also, Command-comma opens the Settings menu.

## Known limitations

- At most three text blocks, each shown for the entire video—no animation, trimming, filters, or stickers, by design.
- The safe-area guides are a reasonable approximation of where Instagram's UI covers a Story, not an exact measurement.
- Output is 8-bit SDR H.264, so HDR sources lose their HDR grade.
- Export requires an FFmpeg installation unless one is bundled into the app.
- The `.app` bundle is ad-hoc signed rather than notarized, so a build copied to another Mac needs right-click → Open the first time. Building it yourself avoids this entirely.
- The app is *not* sandboxed, because it launches FFmpeg and reads and writes files you pick anywhere on disk.

***

## Info for nerds 

### Project layout
See [DEVELOPING.md](DEVELOPING.md) for the file-by-file map, the headless smoke test, and release notes in [CHANGELOG.md](CHANGELOG.md).

### Developing

To run straight from source without installing, which is the fast loop while editing:

```bash
swift run
```

Or open the package in Xcode with `open Package.swift` and run the StoryStamper scheme. There is no `.xcodeproj`—Xcode reads the Swift package directly. `./Scripts/make-app.sh` without `--install` leaves the bundle in `build/` instead of `/Applications`.

The app icon is generated from [Scripts/make-icon.swift](Scripts/make-icon.swift) during the build, so there is no binary asset to maintain. The app looks for FFmpeg first inside its own Resources folder, then at `/opt/homebrew/bin`, `/usr/local/bin`, and `/opt/local/bin`; preview and editing work without FFmpeg, and only export requires it. If you place a standalone `ffmpeg` binary at `Support/ffmpeg` before building, it is bundled into the app so it needs no Homebrew installation at all.

### How the renderer works

The core design goal is that the export matches the preview exactly, so both are fed by the same pixels:

1. **Core Graphics renders each text block once**—font, color, alignment, rounded background box, and drop shadow (when there is no box)—at full source-video resolution ([OverlayRenderer.swift](Sources/StoryStamper/Rendering/OverlayRenderer.swift)).
2. **The preview displays those same bitmaps**, scaled into the aspect-fit video rect. Each block's position is stored in normalized (0...1) video coordinates, so resizing the window never moves the exported text.
3. **On export**, every block is composited onto one transparent canvas at full video size, saved as a temporary PNG, and FFmpeg overlays it at (0, 0) for the whole duration ([VideoExporter.swift](Sources/StoryStamper/Export/VideoExporter.swift)).
4. Output is H.264 plus AAC audio in an MP4 with `+faststart`. Dimensions, frame rate, and audio come straight from the source. Temporary files are deleted afterward.

Encoding uses Apple's hardware encoder (`h264_videotoolbox`) whenever the installed FFmpeg provides it, which on Apple Silicon is dramatically faster than software encoding—a 38-second 4K clip exports in about 20 seconds instead of over ten minutes. Builds without it fall back to libx264 automatically. Audio is remuxed untouched when the source is already AAC, avoiding a needless re-encode.

Text size and padding are authored against a 1080-wide frame and scaled to the actual video, so a given size setting looks the same on 1080p and 4K footage rather than rendering half as large on 4K.

Because the text never passes through a shell or an FFmpeg filter string—arguments go directly to `Process` as an array, and the text lives only inside a PNG—apostrophes, quotes, colons, percent signs, emoji, and multiline input are all safe.

Rotation is handled carefully: FFmpeg auto-rotates phone footage upright before compositing, and the exporter strips the source's display-matrix side data so players do not rotate the already-upright frame a second time.

***

## License

Public domain, via [The Unlicense](LICENSE). Copy it, change it, sell it, ship it—no attribution required, no conditions attached.

Note that FFmpeg is a separate project under its own license (LGPL or GPL, depending on the build). Nothing changes if you install it with Homebrew as described above, since it stays a separate program on your machine. If you ever bundle an `ffmpeg` binary inside the app and distribute that, FFmpeg's license terms apply to the copy you ship.
