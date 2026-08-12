# Changelog

Purpose of this document: a human-readable record of user-visible changes per version. Newest first.

## 2.0.0 — 2026-08-12

The consistency audit is finished and its file is gone. 1.9.0 through 1.9.2 did the work; this closes the last three things and cuts the version that says so.

- **The filename in the left sidebar has lost its hover label.** It held the full path, which is wider than the pane the label pops up in—so it clipped at both ends and told you less than the filename already showing. VoiceOver still reads the whole path, where length costs nothing. That is the same split the color swatches settled on: the spoken label carries what the pixels cannot.
- **The ring around the X over the video is full white**, matching the glyph inside it. At a third opacity it read as a smudge on the footage rather than as the edge of a button; the dark fill is what separates the control from the video, and the ring's job is only to finish its edge.
- The hint under the export button reads **"Enter text to export."** The panel is already called Story Text.

Every finding from the audit is now either fixed or written down as a decision in the places that would otherwise look like drift—DEVELOPING.md for the quit alert and the sheet shapes, the code itself for the preview's two insets. Nothing was left in a file that had to be remembered.

## 1.9.2 — 2026-08-12

The last of the consistency audit that could be settled without looking at the running app. Almost none of this is visible; the point of it is that the next change cannot quietly undo the previous ones.

- **The About box's repository line is one sentence on its own line, with the link below it.** The two used to share a row, which left the sentence wrapping short and the link crowded against it.
- **The style checker now enforces two rules the docs had only stated.** No force unwraps and no debug writes to stderr, across all of the source rather than just the views. A debug write carrying a force unwrap shipped in a release build once; both rules were already written down and neither was checked. It still runs in about 70 milliseconds.
- **Quitting keeps its alert, and now says why.** Everything else the app tells you is a sheet, and a reader was entitled to think the quit prompt was drift. It is not: the close has to be vetoed synchronously and a sheet cannot answer in time. The reasoning lives in DEVELOPING.md and beside the code that makes the "one place a failure is shown" claim, rather than in a chat log.
- The README had gone stale against the app's own vocabulary—it still said Choose Video and Add Text Block, spelled "cancelled" the British way, and described the temporary-file sweep happening at quit when quitting only moves it aside. The file map in DEVELOPING.md was missing five files that exist.
- Two design-system doc comments were fixed rather than their values: `.appRegularBold` no longer claims sheet titles, which is the ambiguity that made two of the four sheets three points smaller than the others. The preview's two inset scales now record why they differ.

## 1.9.1 — 2026-08-12

- **The style sidebar scrolls while it is greyed out.** With no video loaded the whole panel was disabled, and disabling a form disables its scroll view along with its controls—so at a short window you could see there was more below and had no way to reach it. The controls are now greyed section by section, and the panel scrolls either way.
- **No ellipses on commands.** 1.9.0 added them to everything that opens a panel, which is the platform convention and, in an app with a dozen commands of which five take one, read as noise. Open Video, Replace Video, Export Video, Settings, and About are plain again. This is now a deliberate house rule rather than an oversight.
- **Add Block and Remove Block**, in the sidebar, the Text menu, and the undo stack alike. The section is already called Story Text and the menu is already called Text; the noun was carrying the word twice.
- Three lines of helper text are gone. Blocks snapping to the midlines is what dragging one shows you in the first second, styling applying to the selected block is what selecting one means, and the padding hint now reads "Instagram native padding: 20" rather than hedging about it. All three cost vertical space in a sidebar that has none to spare.

## 1.9.0 — 2026-08-12

The first pass of a full consistency audit. Mostly words, and the places where one action had picked up three names.

- **One name per action, everywhere it appears.** Loading a video was called Open in the File menu, Replace in the sidebar, and Choose on the drop screen and in the panel title—two of them visible at once on the empty screen. It is now **Open Video…** until something is loaded and **Replace Video…** afterwards, in all four places. Unloading was called Unload on the button and Clear in the undo stack, so clicking the X and opening the Edit menu gave you "Undo Clear Video"; both say **Unload Video** now. The sidebar's **Remove** button, sitting next to Add Text Block, is now **Remove Text Block** like its menu item.
- **Commands that open a panel say so.** Every command that asks something before it acts now ends in an ellipsis—Open, Replace, Export, Settings, About. Export Video in particular used to read as though it started the export on click, when a save panel comes first.
- **Quitting only asks when there is something to lose.** It used to ask whenever a video was loaded, even with nothing typed—guarding a file path the app deliberately never remembers between launches. It now asks only when story text would be discarded. A running export still asks, since that genuinely throws work away.
- **The opacity slider and the custom color well have lost their hover labels.** What they said is now read out by VoiceOver instead, which is where it was actually needed. Following the color swatches in 1.8.3, nothing in the style sidebar interrupts a drag with a tooltip any more.
- **The export sheet talks to VoiceOver.** The progress bar has a name and reads out the same percentage and estimate shown on screen, and finishing or failing is announced—both used to swap the sheet's contents silently, which a screen reader had no reason to notice.
- **The style sidebar can be resized from the keyboard.** The splitter announced itself to assistive software and then could not be operated by anything but a mouse. It now takes focus, draws the same halo every other self-drawn control does, and moves in 16-point steps with the arrow keys.
- The video's details in the sidebar read properly aloud—"1080 by 1920" rather than "1080 times 1920"—and the filename gives VoiceOver its full path instead of the middle-truncated version on screen.
- Named colors have a home. Success and warning now come from `Palette` rather than being written into the two sheets that use them, and `check-style.sh` fails on a bare color hue in a view the same way it already failed on a bare number.
- The four sheets share their typography, padding, and heading size. Export and failure titles were three points smaller than About and Settings, because two entries in the design system both claimed to be the sheet-title font.
- Frame sizes and frame rates are formatted in one place, like playback time already was. The smoke test reported "30.0 fps" for a file the sidebar called "30 fps".
- Copy fixes: an em-dash with spaces around it in the export estimate, "cancelled" against the app's own American spelling, Instagram's Story lowercased in two places (once twice in the same sentence), "Export size" among fifteen Title Case labels, and a mid-sentence "Text Block".
- Three doc comments told the next person that failure titles are sentence case. All five of them are Title Case, and always have been.

## 1.8.3 — 2026-08-12

- **The name under each Font, Alignment, and Theme picker sits under the glyph it names.** 1.8.1 stopped those names being clipped by pinning the first and last of them to the outer edge of the control, which fixed the clipping and left every short name off to one side—"Dark" sat eleven points to the right of the moon, "System" and "Bold" a few points to the left of their own icons. Each name is now centered on its segment, and pulled back in only by however much it would actually hang off the end. Only "Monospace" is wide enough to need that, and it moves half as far as it used to.
- **The blue focus ring no longer appears when you click.** Clicking a control focuses it, so the ring was announcing something you had just done with your own mouse—around a picker that was working, it read like a validation error. Tabbing to a control still rings it, which is the only thing it was ever for. This applies to every control that draws its own focus: the pickers, the color swatches, the play and close buttons, and the padding shortcut.
- **The color swatches have lost their hover labels.** A swatch already shows its color, and the ring and tick already show which one is on, so naming it on hover repeated both. They keep their spoken labels for VoiceOver.
- Reworded the export size note in Settings to say plainly what a 4K export costs you, and what Instagram does with it. The setting's other option is now called Original quality rather than Match the source.

## 1.8.2 — 2026-08-12

- **Undo, at last.** Command-Z takes back clearing a video, adding or removing a text block, a style change, and a move—whether you moved the block by dragging it or with the arrow keys. Command-Shift-Z puts it back. The Edit menu names the step, so it reads "Undo Move Text Block" rather than a greyed-out word. One continuous slider drag is one undo, not ninety, and undoing a cleared video restores the clip without re-reading it from disk.
- **The confirmation prompt is gone, and deliberately.** A warning and an undo stack are two answers to the same question, and the warning was the worse one: it charged a click on the app's most common path—clearing a clip to start the next one—for a mistake Command-Z now takes back completely. The Confirm before deletion setting has gone with it. Quitting still asks, because quitting is the one thing undo cannot reach.
- **One error, one place, always selectable.** A file that would not load opened an alert; an export that failed opened a sheet, and only the sheet let you select the text—backwards, given FFmpeg's messages are the ones people paste into a bug report. Both now come up as the same sheet, and you can select all of it. A failed export turns into that sheet in place rather than dismissing one and opening another.
- **Command-W no longer leaves the app running with no window.** Closing the last window quits this app, so it asks the same question Command-Q does—but AppKit closed the window before asking, and declining left nothing on screen. The question now comes first, and declining leaves the window exactly where it was. Command-Q still only asks once.
- Under the hood: `Scripts/check-style.sh` enforces the rule the design system only used to state—no raw numbers in a view, covering color alpha, motion, and stroke patterns as well as geometry. It runs before every release build and takes about 40 ms. Two literals it found have moved into named tokens.
- Under the hood: `StoryProject` now removes its playback observers and cancels its outstanding work when it goes away. Nothing leaked, because the app holds exactly one for its whole life—but that was a fact about the app rather than about the class.

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
