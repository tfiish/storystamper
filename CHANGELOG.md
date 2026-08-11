# Changelog

Purpose of this document: a human-readable record of user-visible changes per version. Newest first.

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
