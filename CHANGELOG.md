# Changelog

Purpose of this document: a human-readable record of user-visible changes per version. Newest first.

## 1.8.1 — 2026-08-12

- The monospaced font is now called Monospace, and the names under the Font, Alignment, and Theme pickers no longer run past the edge of the control and get clipped. The first and last names grow inward from their edge rather than centering past it.
- Removed the hover labels from those three pickers. The name underneath already says which option is selected, so the tooltip repeated it.

## 1.8.0 — 2026-08-12

- **Fixed: the X cleared a loaded video without asking**, even with Confirm before deletion switched on, whenever nothing had been typed yet. The setting now decides on its own whether to ask, which is what its description always promised.
- **Exports are sized to the Story frame by default.** Instagram serves Stories at 1080 × 1920, so re-encoding a 4K clip at 4K spent the time and the upload on pixels the destination discards. On the 4K test clip that is 40 MB in 16 seconds instead of 99 MB in 21. Sources at or below 1080 are never enlarged, and Settings can switch back to matching the source. Text is now rasterized at the output size rather than drawn large and resampled, so it is sharper as well.
- **Typing and dragging no longer wait on drawing.** Rasterizing a text block is proportional to the video's resolution, and it was happening on the main thread on every keystroke and every slider frame. It now runs off the main actor, coalesced, holding the previous image until the new one is ready.
- **Quitting and launching no longer wait on the file system.** Quitting renames the scratch directory instead of deleting it; the next launch clears it in the background. A killed 4K export could otherwise have left gigabytes to delete before the window appeared.
- One tooltip everywhere. Every named control now draws the app's own hover label after a quarter second, instead of some controls being fast and the rest waiting on the system's unsettable delay.
- The name under each Font, Alignment, and Theme picker is centered beneath the button it describes.
- Remove Text Block moved off Command-Delete, which is delete-to-beginning-of-line in any text field and was stealing the key while you typed. It is now Command-Shift-Delete, and Area Guides moved off Command-G, which is Find Next everywhere else, to Command-Shift-A.
- The Block picker no longer appears when the second block does, which used to shift every control below it.
- The right sidebar's hint reads "Load a video to enable these controls", since it now describes the whole panel.
- What carries between launches is the selected block's styling, a rule that can be stated in one sentence. It used to be whichever block you last edited.
- The minimum window is taller, so the style sidebar does not scroll at its smallest size.
- The smoke test times each phase, and DEVELOPING.md documents how to measure a change before and after.

## 1.7.0 — 2026-08-12

- **A menu bar.** Every action the app can perform now has a menu item: Open and Replace Video (Command-O), Export Video (Command-E), Add and Remove Text Block, Select Block 1 through 3, Play and Pause, Unload Video, Area Guides (Command-G), and Theme. About in the app menu opens the app's own About box rather than the system panel, and Settings is where macOS expects it at Command-comma.
- **Font, Alignment, and Theme are a new control** rather than a system segmented picker. It shows its own hover label after a quarter second instead of the system tooltip's unsettable delay of roughly a second, it draws a focus ring, and the arrow keys move between options. A caption under each one names the current choice in words, since a row of symbols never says which is on.
- **Theme is its own section**, not a row under Preview—it changes the whole app, including the open, save, and color panels.
- **Keyboard focus is visible** on the controls that draw themselves: the swatches, the close and play buttons, the padding shortcut, and the new pickers. They previously had no focus indicator at all.
- The style sidebar is disabled until a video is loaded. Every control in it edits an overlay that cannot exist yet, and only one of them said so.
- Removed the helper text under Add Text Block, and replaced the note about the 1080-wide reference frame with something a user has reason to care about: style changes apply only to the selected block.
- Under the hood: shared components for the slider rows, color rows, icon buttons, and pickers, so there is one implementation of each rather than three; and a folder layout that separates value types, app state, support, and views.
- [DEVELOPING.md](DEVELOPING.md) opens with rule zero—this app is lightweight, and anything that would substantially slow down launch, editing, or export should not be implemented.

## 1.6.1 — 2026-08-12

- Choose Video, Replace Video, Export Video, and Settings no longer take an ellipsis, so the four buttons that open something are punctuated alike.
- The empty state offers Choose Video once rather than twice—the drop prompt keeps it, and the sidebar just reports that no video is loaded.
- The selected color swatch now shows a tick as well as a ring, so selection is not carried by color alone.
- The Opacity slider says why it stops at 10%, and points at the Text Background checkbox for removing the box entirely.
- Text Style now says that size and padding are relative to a 1080-wide frame, which is why the same numbers look right on 1080p and 4K.
- The export sheet's once-a-second clock runs only while an export is running, instead of ticking through the finished and failed states as well.
- The window's minimum height is now composed from the story text field's minimum plus the chrome around it, so raising one raises the other rather than quietly introducing a scroll.
- Documented, in code, which block's styling is the one that persists between launches: the last one you edited.
- Reworded the Settings checkbox to Confirm before deletion, and the preview toggle to Area Guides.
- The Font picker now shows a real specimen in each typeface it offers, rather than four identical letters. A segmented control replaces styled text with its own font, so the specimens are drawn as images instead, and the specimen is “Aa” rather than one letter because monospace shows in the advance width rather than the letterform.
- The System appearance button is a computer rather than a half-filled circle, and all three tooltips are one word.

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
- Copy and polish: the export sheet's three headings are consistently title case, a failed export is red rather than orange, the video's duration is shown in the sidebar, and “story-safe area guides” is now the term everywhere.
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
