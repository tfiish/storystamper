# Changelog

Purpose of this document: a human-readable record of user-visible changes per version. Newest first.

## 1.2.0 — 2026-08-11

- **Export is dramatically faster.** It now uses Apple's hardware H.264 encoder when available, falling back to libx264 otherwise. A 38-second 4K clip went from over ten minutes to about twenty seconds. Audio is copied rather than re-encoded when the source is already AAC.
- **The progress bar actually works.** FFmpeg's progress stream was being read through an async byte sequence that buffered it into one late lump; it is now read live, so the bar advances continuously and shows an estimated time remaining.
- **Text size no longer shrinks on high-resolution footage.** Sizes are authored against a 1080-wide frame and scaled to the source, so the same setting looks right on both 1080p and 4K.
- Dragging a text block now snaps to the horizontal and vertical midlines, showing a guide line while snapped.
- Added an X button on the video to unload it and return to the drop screen, keeping your text and styling for the next clip.

## 1.1.1 — 2026-08-11

- Added a generated app icon, drawn by `Scripts/make-icon.swift` at build time.
- `Scripts/make-app.sh --install` now copies the app to `/Applications` and registers it with Launch Services.

## 1.1.0 — 2026-08-11

- Support up to two text blocks, each with its own text, style, and position. The controls panel edits the selected block, a dashed ring marks the selection in the preview, and both blocks are burned into the export.
- The smoke test now composites two differently styled blocks on every run.

## 1.0.0 — 2026-08-11

Initial release.

- Drag-and-drop or file-picker loading of MP4, MOV, and M4V videos.
- Live vertical preview with play, pause, scrub, and loop.
- Instagram Story-style text overlay: four font choices, size, alignment, color, and a background box (none, solid, or translucent) with adjustable color, opacity, and padding.
- Direct-manipulation dragging of the text block, plus Top, Center, and Bottom quick positions, stored in normalized video coordinates.
- Toggleable Story safe-area guides (preview only, never exported).
- FFmpeg-based export to H.264 + AAC MP4: preserves source dimensions, frame rate, audio, and orientation—including phone footage with rotation metadata.
- Presentation settings persist between launches; story text does not.
- Headless `--smoke-export` mode for end-to-end pipeline verification.
