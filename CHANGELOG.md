# Changelog

Purpose of this document: a human-readable record of user-visible changes per version. Newest first.

## 1.5.0 — 2026-08-12

- Story Text moved to the top of the right column; the left column now holds the video, preview guides, and About.
- Removed the Top, Center, and Bottom position buttons, since dragging covers positioning.
- The Text Background checkbox now follows its label.
- Padding gained a hint that Instagram's native padding is roughly 20, with the number clickable to jump straight there.
- Adding a text block now requires a loaded video.
- Standardized the interface on a single design system: five text sizes (8, 10, 13, 16, and 21), a four-point spacing grid, and named tokens for radii, borders, icons, and component sizes.

## 1.4.0 — 2026-08-12

- Up to three text blocks instead of two.
- Text Background is now a checkbox beside the section title, with the None/Solid/Translucent modes gone: unchecking dims the controls, and dragging Opacity to 100% gives a solid box.
- Added one-click color swatches beside both color pickers—black, blue, gray, and white for the background, white and black for the text.
- Added an About box in the bottom-left corner explaining what the app is for, with a link to the repository.
- Centered the version label.

## 1.3.0 — 2026-08-11

- Split the controls into two sidebars so nothing needs vertical scrolling. The left holds the video, story text, and preview guides; the right holds text style, text background, position, and export.
- Renamed the Background section to Text Background.
- Added a version label in the bottom-left corner.

## 1.2.0 — 2026-08-11

- **Export is dramatically faster.** It now uses Apple's hardware H.264 encoder when available, falling back to libx264 otherwise. A 38-second 4K clip went from over ten minutes to about twenty seconds. Audio is copied rather than re-encoded when the source is already AAC.
- **The progress bar actually works.** FFmpeg's progress stream was being read through an async byte sequence that buffered it into one late lump; it is now read live, so the bar advances continuously and shows an estimated time remaining.
- **Text size no longer shrinks on high-resolution footage.** Sizes are authored against a 1080-wide frame and scaled to the source, so the same setting looks right on both 1080p and 4K.
- Dragging a text block now snaps to the horizontal and vertical midlines, showing a guide line while snapped.
- Added an X button on the video to unload it and return to the drop screen. It clears the story text back to a single empty block while keeping your styling.

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
