# Changelog

Purpose of this document: a human-readable record of user-visible changes per version. Newest first.

## 1.6.1 — 2026-08-12

- Choose Video, Replace Video, Export Video, and Settings no longer take an ellipsis, so the four buttons that open something are punctuated alike.
- The empty state offers Choose Video once rather than twice—the drop prompt keeps it, and the sidebar just reports that no video is loaded.
- The selected color swatch now shows a tick as well as a ring, so selection is not carried by color alone.
- The Opacity slider says why it stops at 10%, and points at the Text Background checkbox for removing the box entirely.
- Text Style now says that size and padding are relative to a 1080-wide frame, which is why the same numbers look right on 1080p and 4K.
- The export sheet's once-a-second clock runs only while an export is running, instead of ticking through the finished and failed states as well.
- The window's minimum height is now composed from the story text field's minimum plus the chrome around it, so raising one raises the other rather than quietly introducing a scroll.
- Documented, in code, which block's styling is the one that persists between launches: the last one you edited.

## 1.6.0 — 2026-08-12

- **Cancelled and failed exports no longer leave a broken file behind.** FFmpeg now encodes into a scratch folder, and the finished video is moved to your chosen destination only after it completes. That folder is also swept at launch and at quit, so a crash or a force quit cannot leave debris.
- **Quitting asks first** when a video is loaded, and warns separately when an export is running so a long encode cannot be thrown away by a stray Command-Q.
- **Destructive actions confirm.** The X on the video and the Remove button now ask before discarding text you have typed, with a “Don't ask me again” checkbox. A new Settings box in the bottom-left turns that warning back on.
- **Arrow keys reposition text.** Select a block and nudge it with the arrow keys; hold Shift to move farther. Dragging still works exactly as before.
- **The space bar no longer gets stolen from the story text field.** It plays and pauses only while you are not typing.
- **Appearance control**: System, Light, or Dark, applied to the whole app including the open, save, and color panels.
- Font and alignment are now segmented controls showing sample glyphs, with tooltips, instead of a dropdown menu.
- The left sidebar is narrower and its video metadata is condensed to one line; the right sidebar can be resized by dragging the divider beside it. The minimum window width dropped from 1000 to 822 points as a result.
- Accessibility: every icon-only control, slider, and text block now carries a screen-reader label and value. Previously the app had none.
- The open panel and drag-and-drop now enforce the same file types; the panel used to accept formats a drop would reject.
- The export time estimate no longer jumps from “90 seconds” to “2 minutes”.
- Videos with no audio track no longer get pointless audio encoder settings.
- Copy and polish: Export Video takes an ellipsis, the export sheet's three headings are consistently title case, a failed export is red rather than orange, the video's duration is shown in the sidebar, and “story-safe area guides” is now the term everywhere.
- Standardized the remaining untokenized values—color alpha, motion durations, and stroke patterns—so no view inlines a raw number. Removed two text sizes and three other members that nothing used.

## 1.5.0 — 2026-08-12

- Story Text moved to the top of the right column; the left column now holds the video, preview guides, and About.
- Removed the Top, Center, and Bottom position buttons, since dragging covers positioning.
- The Text Background checkbox now follows its label.
- Padding gained a hint that Instagram's native padding is roughly 20, with the number clickable to jump straight there.
- Adding a text block now requires a loaded video.
- Standardized the interface on a single design system: five text sizes (8, 10, 13, 16, and 21), a four-point spacing grid, and named tokens for radii, borders, icons, and component sizes.
- Renamed the export button from Export Story Video to Export Video, and lightened the hint text below it.
- Replaced the blue background swatch with a second gray, so the four sit at even steps from black to white.

## 1.4.0 — 2026-08-12

- Up to three text blocks instead of two.
- Text Background is now a checkbox beside the section title, with the None/Solid/Translucent modes gone: unchecking dims the controls, and dragging Opacity to 100% gives a solid box.
- Added one-click color swatches beside both color pickers—black, blue, gray, and white for the background, white and black for the text. (The blue was replaced by a second gray in 1.5.0.)
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
