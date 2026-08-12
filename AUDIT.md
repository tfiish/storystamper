# Story Stamper — Product Consistency and Implementation Audit

**Audited:** working tree at commit `352d937` plus uncommitted work, version 1.8.3.
**Scope:** every user-facing surface in the repository. Source-only — per [AGENTS.md](AGENTS.md), visual passes belong to the owner, so nothing here rests on having looked at the running app. Section 19 lists what that leaves unevaluated.
**Method:** every line of all 41 Swift files read, plus `Scripts/`, `Support/Info.plist`, and the three docs. `swift build` clean. `./Scripts/check-style.sh` passing.

> **Note on a moving tree.** The working tree changed twice during this audit — `GlyphPicker`, `ColorRow`, `FocusHaloModifier`, `SettingsView`, and the version files were all edited while it was being written. Every finding below was **re-verified against the tree as it stands now**, and the items that were fixed mid-audit are recorded as resolved rather than silently dropped. Line numbers were current as of the final audit pass.

---

## STATUS — remediation pass, 1.9.0

Everything below was fixed and shipped in 1.9.0. **Line numbers in the findings predate those fixes.**

**All 18 quick wins.** Plus T4 (straight quotes in the FFmpeg message), which was in §7 but not the quick-win table.

**Larger items done:** H1 (vocabulary), H3 (ellipses), H5 (quit gate), H6 (Remove label), M1/S2 (`SheetChrome.swift` — shared title, base font, padding, width rule), M2 (Done everywhere), M3 (mid-sentence casing), M6/A2/R4 (`SidebarSplitter` keyboard support), M10 (doc comments), S1/R2 (`Palette` + checker rule), A1 (hover/accessibility parity), A4 (spoken metadata), ST1/A3 (`Announcement.swift`, progress labelling), X1 (`VideoInfo.dimensions`/`frameRate`), X2 (flag documented), F1 (hint verb), V2, V3, I2, I3, C3.

**Resolved by your own edits mid-audit:** I1 (the `PROBE` write), M8 (`ExportResolution` casing — "Original quality" / "Story (1080)" now agree).

**Reclassified after a closer look, no change made:** L8 (icon weight). The four icons serve three roles — hero, status, empty state — and the two that share a role already match. Forcing the other two to agree would be uniformity for its own sake.

**Still open:** H2 is done, H4 is a documented decision, and what remains is listed in §19 plus the two judgment calls in the closing note.

### Reversed after review, 1.9.1

**H3 (ellipses) is withdrawn.** Ellipses were added on every command that opens a panel, and removed again: five of this app's dozen commands take one, and the result read as noise. **This is now a deliberate house convention, recorded in DEVELOPING.md — do not re-raise it.** The one remaining ellipsis, `"Finishing up…"` in the export sheet, is a progress string rather than a command label and stays.

**H6/M3 landed shorter than recommended.** The audit proposed standardizing on *Add Text Block* / *Remove Text Block*; the shipped names are **Add Block** / **Remove Block**, applied across the sidebar, the menu, the undo stack, and the VoiceOver labels. The section is already called Story Text and the menu is already called Text, so the noun was carrying "text" twice. The one-name-per-action rule holds; the name is just shorter.

**Three helper lines deleted rather than reworded.** "Blocks snap to the midlines", the whole "Style changes apply only to the selected text block" line, and the hedge in the padding hint (now "Instagram native padding:"). Self-evident copy costs vertical space in a 260 pt sidebar and is read once. Noted in DEVELOPING.md as a standing rule.

---

---

## 1. Repository / Product Map

**One product, one surface.** Story Stamper is a single-window macOS SwiftUI utility that burns text overlays into vertical video via FFmpeg. Swift Package Manager, no `.xcodeproj`. ~3,900 lines.

**Surfaces**

| Surface | Entry point | Files |
| --- | --- | --- |
| Main window | `Window("Story Stamper", id: "main")` | [StoryStamperApp.swift:25](Sources/StoryStamper/StoryStamperApp.swift:25), [MainWindowView.swift](Sources/StoryStamper/Views/MainWindowView.swift) |
| Left pane — source | fixed 200 pt | [SourceSidebarView.swift](Sources/StoryStamper/Views/SourceSidebarView.swift) |
| Center pane — preview | drop zone / player / transport | [VideoPreviewView.swift](Sources/StoryStamper/Views/VideoPreviewView.swift) |
| Right pane — style | resizable 260–380 pt | [StyleSidebarView.swift](Sources/StoryStamper/Views/StyleSidebarView.swift) |
| Menu bar | `Commands` | [StoryCommands.swift](Sources/StoryStamper/Views/StoryCommands.swift) |
| Sheets ×4 | About, Settings, Export status, Failure | [AboutView](Sources/StoryStamper/Views/AboutView.swift), [SettingsView](Sources/StoryStamper/Views/SettingsView.swift), [ExportStatusView](Sources/StoryStamper/Views/ExportStatusView.swift), [FailureSheet](Sources/StoryStamper/Views/FailureSheet.swift) |
| Modal alerts ×2 | quit confirmation | [StoryStamperApp.swift:112-145](Sources/StoryStamper/StoryStamperApp.swift:112) |
| System panels | open, save, color | `NSOpenPanel`, `NSSavePanel`, `ColorPicker` |
| Headless CLI | `--smoke-export` | [SmokeTest.swift](Sources/StoryStamper/SmokeTest.swift) |
| Build tooling | app bundle, icon, style gate | `Scripts/` |

**Shared component layer** (9): `BarStrip`, `ColorRow`, `FocusHaloModifier`, `FontSample`, `GlyphPicker`, `HoverLabel`, `IconButton`, `SidebarSplitter`, `SliderRow`.

**Workflows:** load (drop / panel / menu) → type → style → place (drag, arrow keys) → export (save panel → progress → complete or fail). Secondary: theme switch, guides toggle, export-size setting, sidebar resize, undo/redo, quit.

**States that exist in code:** no video, video loaded, 1–3 blocks, block selected, text empty vs present, drop-targeted, playing/paused, scrubbing, snapped-to-midline, keyboard-focused preview, exporting, export complete, failure (5 export causes, 3 probe causes), disabled style panel, quit-with-work-pending.

**Concepts named repeatedly:** video, story text, text block, style, background, padding, Story frame, safe area / area guides, theme, export.

**Deliberately absent** (enforced by AGENTS.md): accounts, roles, permissions, network, analytics, multi-window, timeline, trimming, animation, >3 blocks.

---

## 2. Executive Summary

This is a disciplined codebase, and the audit should say so plainly before it lists faults. The numeric design system is not aspirational — it is **specified** ([DesignSystem.swift](Sources/StoryStamper/DesignSystem/DesignSystem.swift)), **documented** ([DEVELOPING.md](DEVELOPING.md) §Design system), and **mechanically enforced** ([Scripts/check-style.sh](Scripts/check-style.sh), wired into `make-app.sh:17`). I ran the checker: it passes. I verified its claims independently — every `.font(.system(size:))` in the codebase sits on an `Image`, never a `Text`; no SwiftUI semantic font style (`.caption`, `.title3`, …) appears anywhere; menu and sidebar disabled-conditions match on all five paired actions. The usual harvest of a consistency audit — near-miss spacing, forked components, drifting type ramps — is essentially **absent**. That is rare and worth protecting.

The real inconsistencies live in three places the checker cannot see:

1. **Words.** There is no vocabulary discipline matching the numeric discipline. One action to load a video is called *Open*, *Replace*, and *Choose*; one action to discard it is called *Unload* in the UI and *Clear* in the undo stack, so the Edit menu contradicts the button the user just clicked. The core noun is *Text Block*, *Block*, and *text block* depending on where you look.

2. **Sheets.** Four sheets, no shared primitive, two incompatible archetypes — different title fonts for the same hierarchical level, different widths, different dismiss verbs, different base-font handling. Plus a fifth presentation system (`NSAlert`) used only for quitting, which contradicts the codebase's own stated goal of one place errors appear.

3. **The untokenized half of the design system.** `DesignSystem.swift` governs every *number* the interface draws with. It governs no *color* and no *emphasis*. Status colors (`.orange`, `.green`), the muted-text ramp (`.secondary` ×17, `.tertiary` ×1), and icon weights are one-offs by default because there is no token to reach for. This is the root cause of several low-priority findings and the most likely source of future drift.

One item needs attention beyond consistency: the **quit confirmation prompts when nothing is at stake**, contradicting the app's documented decision to prefer undo over prompts.

Counts: **6 high**, **12 medium**, **12 low**, **4 systemic roots**. One further high-priority item — a debug `PROBE` statement writing to stderr, carrying the codebase's only force unwrap — was present in the working tree when the audit began and **was fixed before it finished**; it is recorded at I1 for the record only.

---

## 3. Highest-Priority Findings

### H1 — One action, three names: loading a video

| Where | Label |
| --- | --- |
| [StoryCommands.swift:25](Sources/StoryStamper/Views/StoryCommands.swift:25) | `"Open Video"` (no video) / `"Replace Video"` (video loaded) |
| [SourceSidebarView.swift:61](Sources/StoryStamper/Views/SourceSidebarView.swift:61) | `"Replace Video"` |
| [VideoPreviewView.swift:81](Sources/StoryStamper/Views/VideoPreviewView.swift:81) | `"Choose Video"` |
| [StoryProject.swift:442](Sources/StoryStamper/State/StoryProject.swift:442) | panel title `"Choose Video"` |

All four call `chooseVideo()`. **Why it matters:** in the empty state the user sees a button reading *Choose Video* while the File menu directly above reads *Open Video* — two names for one action, visible simultaneously. **Intended convention:** the menu's state-dependence is right (macOS convention is *Open…* when nothing is loaded); the drop prompt should match it. **Recommendation:** standardize on **Open Video…** / **Replace Video…**, set the `NSOpenPanel` title to match the state, and change the drop-prompt button to `Open Video…`. **Systemic** — same root as H2, H6 (see S3).

### H2 — The undo stack contradicts the button that was just clicked

The X over the video is labeled `"Unload video and clear story text"` ([VideoPreviewView.swift:144](Sources/StoryStamper/Views/VideoPreviewView.swift:144)); the menu item is `"Unload Video"` ([StoryCommands.swift:67](Sources/StoryStamper/Views/StoryCommands.swift:67)). Both call `requestClearVideo()`, which registers its undo step as `"Clear Video"` ([StoryProject.swift:492](Sources/StoryStamper/State/StoryProject.swift:492)).

**Why it matters:** the user clicks *Unload*, opens Edit, and reads **Undo Clear Video**. Undo action names are among the few strings macOS surfaces in a *different* menu from the control that caused them, so a mismatch here is unusually visible. This also matters more since 1.8.0 removed the confirmation prompt in favor of undo — undo is now the entire safety net, and its label is wrong. **Recommendation:** rename the undo action to `"Unload Video"`. One-line fix at `StoryProject.swift:492`. **Isolated**, but check the other three undo names (`"Add Text Block"`, `"Remove Text Block"`, `"Text Style"`, `"Move Text Block"`) against their triggers — those four do match.

### H3 — No ellipsis on any command that opens a dialog

Every one of these opens a panel, sheet, or window and none carries `…`:

- `"Settings"` — [StoryCommands.swift:19](Sources/StoryStamper/Views/StoryCommands.swift:19), [SourceSidebarView.swift:32](Sources/StoryStamper/Views/SourceSidebarView.swift:32)
- `"About"` / `"About Story Stamper"` — [SourceSidebarView.swift:34](Sources/StoryStamper/Views/SourceSidebarView.swift:34), [StoryCommands.swift:15](Sources/StoryStamper/Views/StoryCommands.swift:15)
- `"Open Video"` / `"Replace Video"` — [StoryCommands.swift:25](Sources/StoryStamper/Views/StoryCommands.swift:25)
- `"Replace Video"` — [SourceSidebarView.swift:61](Sources/StoryStamper/Views/SourceSidebarView.swift:61)
- `"Choose Video"` — [VideoPreviewView.swift:81](Sources/StoryStamper/Views/VideoPreviewView.swift:81)
- `"Export Video"` — [StoryCommands.swift:33](Sources/StoryStamper/Views/StoryCommands.swift:33), [StyleSidebarView.swift:189](Sources/StoryStamper/Views/StyleSidebarView.swift:189)

The only true ellipsis in the app is `"Finishing up…"` ([ExportStatusView.swift:87](Sources/StoryStamper/Views/ExportStatusView.swift:87)) — so the character is available and the omission is uniform rather than accidental.

**Why it matters:** on macOS the ellipsis is load-bearing information — it promises the command will ask before doing anything. Its absence on *Export Video* is the costly one: the label currently implies the export starts on click, when in fact a save panel appears first. **Intended convention:** Apple HIG — trailing ellipsis when a command requires further input. **Recommendation:** add `…` to all of the above. Consider leaving the sidebar's *Export Video* button without one if the footer hint already sets the expectation — but the **menu item** should have it. **Systemic**, single sweep.

### H4 — Two dialog systems for two kinds of question

Everything the app tells the user goes through a SwiftUI sheet — except quitting, which uses `NSAlert` ([StoryStamperApp.swift:137-145](Sources/StoryStamper/StoryStamperApp.swift:137)). That is the only `NSAlert` in the codebase.

This conflicts with [FailureSheet.swift:3](Sources/StoryStamper/Views/FailureSheet.swift:3) — *"The one place a failure is shown, whichever half of the app produced it"* — and with [StoryFailure.swift:5-8](Sources/StoryStamper/Models/StoryFailure.swift:5), which documents consolidating away exactly this kind of split (*"a probe error went to an alert, an export error went to a sheet"*). The consolidation covered failures but not confirmations.

**Why it matters:** the two systems have different typography, button ordering, icon treatment, and dismissal. A warning triangle in `FailureSheet` is `.orange` SF Symbol at `IconSize.status`; the alert's is AppKit's own. **Nuance:** this one is partly defensible — `NSAlert` runs a modal loop, which is what lets `windowShouldClose` return a synchronous `Bool`, and [WindowCloseGuard.swift:6-9](Sources/StoryStamper/Support/WindowCloseGuard.swift:6) explains why that hook is the only workable one. A SwiftUI sheet cannot answer synchronously. **Recommendation:** keep `NSAlert` for the quit path — the constraint is real — but document the exception where the "one place" claim is made, so the next reader doesn't treat it as drift. If visual unity matters more, the alternative is deferring termination and driving a sheet, which is materially more complex. **Product judgment.**

### H5 — Quit prompts when there is nothing to lose

[StoryStamperApp.swift:124](Sources/StoryStamper/StoryStamperApp.swift:124) prompts whenever `project.video != nil`, regardless of whether any text has been typed. With no text, the message reads *"The loaded video will be discarded."*

Three things sit against this:

1. **The app's own stated philosophy.** [StoryProject.swift:419-422](Sources/StoryStamper/State/StoryProject.swift:419): *"There is no confirmation prompt any more, and deliberately so. A warning and an undo stack are two answers to the same question, and the prompt was the worse one — it charged a click on the app's most common path for a mistake…"*
2. **The 1.8.0 change itself**, which removed the prompt from the X button for precisely the no-text-typed case.
3. **Nothing is actually discarded.** The source file is untouched ([AboutView.swift:29](Sources/StoryStamper/Views/AboutView.swift:29): *"the original video is never modified"*), and the app deliberately does not remember which video was open ([SettingsStore.swift:4-5](Sources/StoryStamper/Support/SettingsStore.swift:4)). With no text typed, quitting loses only a file path the app would discard on purpose anyway.

**Why it matters:** it charges a click on every quit after any load, protecting nothing, in an app whose first principle is that it must feel fast. **Recommendation:** gate on `project.hasStoryText` rather than `project.video != nil`, and drop the now-dead no-text message variant at line 129. The export-running branch (line 115) should stay — that genuinely destroys work. **Isolated, one-line.**

### H6 — "Add Text Block" beside "Remove"

[StyleSidebarView.swift:56, 61](Sources/StoryStamper/Views/StyleSidebarView.swift:56) place these two buttons in one `HStack`. The menu equivalents are `"Add Text Block"` and `"Remove Text Block"` ([StoryCommands.swift:39, 46](Sources/StoryStamper/Views/StoryCommands.swift:39)).

**Why it matters:** the pair is asymmetric where symmetry is free, and the sidebar's *Remove* is ambiguous next to a Story Text field — remove the text, or the block? The menu is unambiguous; the sidebar is not. **Recommendation:** make the sidebar read `"Remove Text Block"` to match, or if width is the constraint (the sidebar floor is 260 pt), shorten **both** to `"Add"` / `"Remove"` and let the section header carry the noun. Matching the menu is preferable. **Isolated.**

---

## 4. Systemic Consistency Problems

Four roots account for most of what follows.

### S1 — The design system tokenizes numbers, not color or emphasis

[DesignSystem.swift:3](Sources/StoryStamper/DesignSystem/DesignSystem.swift:3) opens: *"The single source of truth for every number the interface draws with."* Taken literally, and it is enforced literally — `Opacity` tokenizes alpha, `Motion` tokenizes duration, `Stroke` tokenizes dash patterns. There is **no color token and no emphasis token anywhere in the file.**

Consequences, all of which are one-offs because nothing exists to reach for:

- Status colors are raw: `.orange` ([FailureSheet.swift:14](Sources/StoryStamper/Views/FailureSheet.swift:14)), `.green` ([ExportStatusView.swift:24](Sources/StoryStamper/Views/ExportStatusView.swift:24)). Two semantic colors, zero definitions.
- The muted-text ramp is convention-only: `.secondary` 17 times, `.tertiary` exactly once ([SourceSidebarView.swift:39](Sources/StoryStamper/Views/SourceSidebarView.swift:39)).
- Icon weight is unspecified: three hero icons take the default, one takes `.light` (see L8).

**Recommendation:** add a `Palette` (or `Status`) group covering success, warning, and the muted-text ramp, and extend `check-style.sh` to flag a bare `.orange`/`.green`/`.red` inside `Views/`. This is small and it closes the one part of the system that is currently held together by habit.

### S2 — No sheet primitive

Four sheets, no shared container, two archetypes that disagree on the typography of the same hierarchical element. See M1.

### S3 — No shared action vocabulary

Button and menu strings are authored at each call site. There is no `enum Strings`, no naming table, and nothing enforcing that the label on a control matches the undo name, the menu item, or the panel title for the same action. Root cause of H1, H2, H6, M3, and part of M8/M9. **The contrast with the numeric system is the whole point:** numbers have one home and a CI gate; words have neither.

### S4 — The style gate stops at `Views/`

[check-style.sh:7-9](Scripts/check-style.sh:7) scopes to `Sources/StoryStamper/Views` and defends the choice: *"the renderer and exporter do arithmetic on pixels rather than drawing chrome."* Mostly sound — but [OverlayRenderer.swift:90-91](Sources/StoryStamper/Rendering/OverlayRenderer.swift:90) draws chrome by any definition, and its raw values escape (see M7). The renderer names its *other* constants carefully (`bleed`, `cornerRadiusRatio`, `minCornerRadius`, `maxCornerRadius`, lines 18-24), which makes the two inline literals look like oversights rather than policy.

---

## 5. Visual and Layout Findings

The token layer is clean; I verified rather than assumed. `check-style.sh` passes, and independent greps for raw literals in `padding`/`frame`/`spacing`/`cornerRadius`/`lineWidth` inside `Views/` return only the two sanctioned exceptions (`spacing: 0` ×5, documented in DEVELOPING.md).

**V1 (Medium) — Two sheet archetypes disagree on title typography.** Detail in M1.

**V2 (Low) — One-off top padding.** [AboutView.swift:44](Sources/StoryStamper/Views/AboutView.swift:44) adds `.padding(.top, Spacing.hair)` to its button row. [SettingsView.swift:29](Sources/StoryStamper/Views/SettingsView.swift:29), the structurally identical row, has none. A 2 pt difference between two sheets a user reaches from adjacent buttons. **Recommendation:** drop it, or move it into a shared sheet container (S2).

**V3 (Low) — `BarStrip` horizontal padding overridden once.** Default `Spacing.medium` (12) is used by both sidebar footers; `TransportBar` passes `Spacing.large` (16) ([VideoPreviewView.swift:329](Sources/StoryStamper/Views/VideoPreviewView.swift:329)). Plausibly deliberate — the transport bar spans a much wider pane — but the parameter carries no comment explaining when to override, so the next caller has no rule. **Recommendation:** one line of doc on `BarStrip.horizontalPadding` stating the rule. **Uncertain — likely intentional.**

**V4 (Low) — Drop-prompt vertical rhythm is uniform where it probably shouldn't be.** [VideoPreviewView.swift:71](Sources/StoryStamper/Views/VideoPreviewView.swift:71) spaces icon, title, subtitle, and button all at `Spacing.large`. `"Drag a video here"` and `"MP4, MOV, or M4V"` are a heading and its caption — a tighter pair than either is to the button. **Needs your eye**; it may read fine. Listed because it is the one place in the app where a title and its own subtitle get the same gap as unrelated siblings.

**V5 (Intentional, noted) — Asymmetric pane separators.** Left pane is divided by `Divider()` ([MainWindowView.swift:50](Sources/StoryStamper/Views/MainWindowView.swift:50)), right by `SidebarSplitter` — which itself wraps a `Divider()` ([SidebarSplitter.swift:17](Sources/StoryStamper/Views/Components/SidebarSplitter.swift:17)), so they render identically. Correct: the affordance differs because the behavior differs. **No action.**

---

## 6. Component and Control Findings

### M1 (Medium) — Four sheets, two archetypes, no shared primitive

| | About / Settings | Export status / Failure |
| --- | --- | --- |
| Width | `.frame(width: Metrics.sheetWidth)` 420 | `.frame(minWidth: Metrics.sheetMinWidth)` 340 |
| Alignment | `VStack(alignment: .leading)` | `VStack` centered |
| Title font | `.appTitle` (16 semibold) | `.appRegularBold` (13 semibold) |
| Divider under title | yes | no |
| Base font | `.font(.appRegular)` on container | none (Export) / per-`Text` (Failure) |
| Dismiss button | trailing, after `Spacer()` | centered |
| Dismiss verb | `"Done"` | `"Done"` (Export) / `"Close"` (Failure) |
| Padding | `Spacing.xLarge` | `Spacing.xLarge` ✓ |

Refs: [AboutView.swift:8-48](Sources/StoryStamper/Views/AboutView.swift:8), [SettingsView.swift:11-37](Sources/StoryStamper/Views/SettingsView.swift:11), [ExportStatusView.swift:10-40](Sources/StoryStamper/Views/ExportStatusView.swift:10), [FailureSheet.swift:11-32](Sources/StoryStamper/Views/FailureSheet.swift:11).

**What conflicts:** the split into *content sheet* vs *status sheet* is a legitimate product distinction — one is a document, the other an outcome. But **the title of a sheet is the same hierarchical element in both**, and it is set two sizes apart. `.appTitle` exists and is documented as *"Prominent headings"*; `.appRegularBold` is documented as *"Emphasized body copy, such as sheet titles"* — the two doc comments in [DesignSystem.swift:26-29](Sources/StoryStamper/DesignSystem/DesignSystem.swift:26) **both** claim sheet titles. The token file itself is ambiguous, which is why the views diverged.

**Recommendation:** decide which token owns a sheet title, fix the doc comment on the loser, and introduce a `Sheet` container component taking a title, a body, and a footer button set — collapsing width, padding, base font, and title treatment into one place. That also fixes M2, V2. **Systemic (S2).**

### M2 (Medium) — Dismiss verb: "Done" ×3 vs "Close" ×1

`"Done"` at [AboutView.swift:41](Sources/StoryStamper/Views/AboutView.swift:41), [SettingsView.swift:31](Sources/StoryStamper/Views/SettingsView.swift:31), [ExportStatusView.swift:32](Sources/StoryStamper/Views/ExportStatusView.swift:32); `"Close"` at [FailureSheet.swift:28](Sources/StoryStamper/Views/FailureSheet.swift:28). All four are dismiss-only — none commits or discards anything.

**Why it matters:** the brief's test — *would a user who learned one predict the other?* — fails here for no reason. **Nuance:** an argument exists that *Done* implies completed work and a failure has none. It is thin; the button does the same thing in all four. **Recommendation:** `"Done"` everywhere, or adopt `"Close"` everywhere. Prefer `"Done"` (three sites already, and it pairs with `.defaultAction`, which all four already set — consistently, to their credit).

### M6 (Medium) — The sidebar splitter cannot be operated by keyboard

[SidebarSplitter.swift](Sources/StoryStamper/Views/Components/SidebarSplitter.swift) has `.accessibilityLabel("Resize style sidebar")` (line 43) but is not `.focusable()`, has no `accessibilityAdjustableAction`, and has no key handling. It is mouse-only.

**What it conflicts with:** [GlyphPicker.swift:78-94](Sources/StoryStamper/Views/Components/GlyphPicker.swift:78) — the app's other custom control — implements `.focusable()`, a focus halo, `.onKeyPress` for left/right arrows, **and** `accessibilityAdjustableAction`. Two custom controls, opposite standards. The label alone arguably makes it worse than having none: VoiceOver announces a control that cannot then be operated.

**Why it matters:** the app is otherwise conscientious here — [StoryCommands.swift:4-7](Sources/StoryStamper/Views/StoryCommands.swift:4) states the principle that *"Everything the app can do has a menu item, which is what makes those actions discoverable, keyboard-reachable, and visible to assistive software."* Sidebar width is the one action with no menu item and no keyboard path. **Recommendation:** mirror `GlyphPicker` — make it focusable with a halo, arrow keys stepping by `Spacing.large`, and an `accessibilityAdjustableAction`. **Isolated but a clear break in an established internal standard.**

**C1 (Low) — Status/hero icons have no primitive.** Four sites build the same thing by hand: [AboutView.swift:10-13](Sources/StoryStamper/Views/AboutView.swift:10) (`IconSize.large`, `.tint`), [FailureSheet.swift:12-15](Sources/StoryStamper/Views/FailureSheet.swift:12) (`IconSize.status`, `.orange`), [ExportStatusView.swift:22-25](Sources/StoryStamper/Views/ExportStatusView.swift:22) (`IconSize.status`, `.green`), [VideoPreviewView.swift:72-75](Sources/StoryStamper/Views/VideoPreviewView.swift:72) (`IconSize.emptyState`, `.secondary`, **`weight: .light`**). Only the fourth sets a weight — see L8. All four correctly set `.accessibilityHidden(true)`. **Recommendation:** low-value to abstract four call sites; instead fix the weight inconsistency and add the color tokens from S1.

**C2 (Reviewed, clean) — `SliderRow`, `ColorRow`, `IconButton`, `GlyphPicker`, `BarStrip`, `HoverLabel`, `FocusHaloModifier`.** No forked or near-duplicate components anywhere. [SliderRow.swift:3-5](Sources/StoryStamper/Views/Components/SliderRow.swift:3) and [BarStrip.swift:3-5](Sources/StoryStamper/Views/Components/BarStrip.swift:3) both document the drift they were created to stop. Three sliders, three glyph pickers, two color rows, three bar strips — each through one implementation. This is the part of the codebase working exactly as intended.

**C3 (Low) — `SliderRow.help` is named after a mechanism it no longer uses.** [SliderRow.swift:16](Sources/StoryStamper/Views/Components/SliderRow.swift:16) declares `var help: String?`, which renders via `hoverLabel` (line 35), not `.help()`. `.help()` was deliberately eliminated app-wide ([HoverLabel.swift:5-8](Sources/StoryStamper/Views/Components/HoverLabel.swift:5)) — I confirmed zero remaining call sites. The parameter name is the last trace. **Recommendation:** rename to `hoverHelp` or `hint`. **Cosmetic.**

---

## 7. Text and Terminology Findings

### M3 (Medium) — The core noun has three forms

| Form | Sites |
| --- | --- |
| `Text Block` | `"Add Text Block"` ×2, `"Remove Text Block"`, `"Move Text Block"` (undo), and mid-sentence at [StyleSidebarView.swift:109](Sources/StoryStamper/Views/StyleSidebarView.swift:109) |
| `Block` | picker label and items `"Block \(n)"` ([StyleSidebarView.swift:39-41](Sources/StoryStamper/Views/StyleSidebarView.swift:39)), `"Select Block \(n)"` ([StoryCommands.swift:53](Sources/StoryStamper/Views/StoryCommands.swift:53)), `"Blocks snap to the midlines"` ([StyleSidebarView.swift:67](Sources/StoryStamper/Views/StyleSidebarView.swift:67)) |
| `text block` | [VideoPreviewView.swift:43](Sources/StoryStamper/Views/VideoPreviewView.swift:43), `"Text block \(n)"` a11y label ([VideoPreviewView.swift:225](Sources/StoryStamper/Views/VideoPreviewView.swift:225)) |

Two distinct problems inside this:

1. **Title Case mid-sentence.** [StyleSidebarView.swift:109](Sources/StoryStamper/Views/StyleSidebarView.swift:109) — *"Style changes apply only to the selected Text Block."* Every other prose reference lowercases it ([VideoPreviewView.swift:43](Sources/StoryStamper/Views/VideoPreviewView.swift:43): *"Arrow keys move the selected text block."*). **Definite.**
2. **The numbered instance has three names** for the same object: `Block 1` (picker), `Select Block 1` (menu), `Text block 1` (VoiceOver).

**Intended convention**, inferable from the majority: Title Case in control labels and menu items, lowercase in prose, and the full noun *text block* when the bare word would be ambiguous. **Recommendation:** lowercase line 109; align the picker/menu/a11y trio on one form — `Block \(n)` inside the Story Text section is fine since context disambiguates, but then the VoiceOver label should say `Block \(n)` too. **Systemic (S3).**

### M4 (Medium) — Em-dash with surrounding spaces, against a stated house rule

[ExportStatusView.swift:95](Sources/StoryStamper/Views/ExportStatusView.swift:95):
```
return "\(percent)% — about \(formatted(remaining)) remaining"
```
Both [AGENTS.md](AGENTS.md) (*"Em-dashes directly between words—no spaces around them"*) and [DEVELOPING.md](DEVELOPING.md) §Style rules state this. I grepped every string literal in the codebase: **this is the only violation**, which makes it a slip rather than a pattern. **Recommendation:** `"\(percent)%—about … remaining"` reads badly around a numeral; prefer restructuring to `"\(percent)%, about \(formatted(remaining)) remaining"`. **Isolated.**

### M8 (Medium) — One picker, two capitalization styles

[ExportResolution.swift:22-24](Sources/StoryStamper/Models/ExportResolution.swift:22): `"Match the source"` (sentence case) and `"Story (1080)"` (title case) sit adjacent in the same `Picker`. **Recommendation:** `"Match the source"` / `"Story frame (1080)"`, or `"Match Source"` / `"Story (1080)"`. Sentence case is the better fit — these read as descriptions, not labels. **Isolated.**

### M9 (Medium) — One sentence-case control label among fifteen

[SettingsView.swift:18](Sources/StoryStamper/Views/SettingsView.swift:18) — `Picker("Export size", …)`. Every other control label in the app is Title Case: *Story Text, Text Style, Text Background, Block, Font, Size, Alignment, Color, Opacity, Padding, Area Guides, Theme, Video, Preview*. **Recommendation:** `"Export Size"`. **Isolated.**

### M10 (Medium) — Three doc comments assert a convention their own values break

All three say *"Sentence-case title"*:
- [StoryFailure.swift:11](Sources/StoryStamper/Models/StoryFailure.swift:11) → values include `"Export Failed"`
- [VideoInfo.swift:50](Sources/StoryStamper/Models/VideoInfo.swift:50) → `"Unsupported File Type"`, `"Could Not Load Video"`
- [ExportError.swift:33](Sources/StoryStamper/Export/ExportError.swift:33) → `"FFmpeg Not Found"`, `"Export Failed"`

Every value is Title Case. **Why it matters:** the comment is the only written specification for failure-title style, so the next person to add an error case gets misled by three files at once. **Recommendation:** the values are consistent with each other and with macOS alert convention — fix the comments to say *"Title Case"*. Cheaper and less risky than rewriting five user-facing strings. **Systemic in cause, trivial to fix.**

**T1 (Medium) — Instagram's "Story" is capitalized inconsistently, including twice within one sentence.**

- [SettingsView.swift:23](Sources/StoryStamper/Views/SettingsView.swift:23) — *"Instagram serves **Stories** at 1080 × 1920. … is not rendered in an Instagram **story**."* Both forms, one string. (This string was rewritten during the audit; the contradiction is new.)
- [SourceSidebarView.swift:91](Sources/StoryStamper/Views/SourceSidebarView.swift:91) — *"…the top and bottom of a **story**."*

Capitalized everywhere else: [AboutView.swift:25](Sources/StoryStamper/Views/AboutView.swift:25), [ExportResolution.swift:23](Sources/StoryStamper/Models/ExportResolution.swift:23) (`"Story (1080)"`), [DesignSystem.swift:131](Sources/StoryStamper/DesignSystem/DesignSystem.swift:131), [DEVELOPING.md](DEVELOPING.md) §Invariants.

**Why it matters:** it is Instagram's product name, and the app's own export mode is called *Story*. Lowercasing it in the Settings sheet that explains that mode undercuts the connection the copy is making. **Recommendation:** capitalize both. **Definite**, raised from Low because one instance now self-contradicts inside a single sentence.

**T2 (Low) — Mixed US/UK spelling.** *"cancelled"* at [StoryStamperApp.swift:118](Sources/StoryStamper/StoryStamperApp.swift:118) (UK) against *"Dark Gray"* / *"Light Gray"* at [OverlayStyle.swift:167-168](Sources/StoryStamper/Models/OverlayStyle.swift:167) (US). **Recommendation:** *"canceled"*. **Isolated.**

**T3 (Low) — App name hardcoded in two menu strings.** `"About Story Stamper"` ([StoryCommands.swift:15](Sources/StoryStamper/Views/StoryCommands.swift:15)) and `"Story Stamper Help"` ([StoryCommands.swift:85](Sources/StoryStamper/Views/StoryCommands.swift:85)) while `AppInfo.displayName` exists and is used at [SourceSidebarView.swift:37](Sources/StoryStamper/Views/SourceSidebarView.swift:37) and [AboutView.swift:15](Sources/StoryStamper/Views/AboutView.swift:15). `Window("Story Stamper", …)` ([StoryStamperApp.swift:25](Sources/StoryStamper/StoryStamperApp.swift:25)) is a third. **Recommendation:** interpolate `AppInfo.displayName`. Low stakes for a single-name app, but it is the same class of drift the rest of the codebase works hard to prevent.

**T4 (Low) — Straight quotes in UI copy.** [ExportError.swift:16](Sources/StoryStamper/Export/ExportError.swift:16): `Install it with \"brew install ffmpeg\"`. The only escaped quotes in any user-visible string. **Recommendation:** typographic quotes, or drop them — a monospace-free sentence reads fine as *Install it with brew install ffmpeg.*

**T5 (Reviewed, clean) — Oxford commas.** Checked every list in UI copy: *"font, colors, background, and padding"* ×2, *"MP4, MOV, or M4V"* ×2, *"scale, composite, and re-encode"*, *"a cancel, a failure, a quit, or a crash"*. All compliant.

---

## 8. Flow and Interaction Findings

**F1 (Medium) — Two hints in one slot answer two different questions.** [StyleSidebarView.swift:196-200](Sources/StoryStamper/Views/StyleSidebarView.swift:196): with no video, *"Load a video to enable these controls."*; with no text, *"Enter story text to export."* The first describes the whole panel, the second describes only the button. They occupy the same position under the same button. Also, *"Load a video"* is a fourth verb for H1's action (*Open*/*Replace*/*Choose*/*Load*). **Recommendation:** unify the frame — *"Open a video to enable these controls."* / *"Enter story text to export."* — and fold the verb into the H1 sweep.

**F2 (Low) — Two inset scales in the preview pane.** The canvas insets by `Spacing.medium` ([VideoPreviewView.swift:120](Sources/StoryStamper/Views/VideoPreviewView.swift:120)); the drop-target ring insets by `Spacing.small` ([VideoPreviewView.swift:33](Sources/StoryStamper/Views/VideoPreviewView.swift:33)). Different tokens for two frames drawn in the same rectangle. Possibly deliberate — the ring should sit outside the content — but nothing records the intent. **Uncertain.**

**F3 (Reviewed, clean) — Menu/sidebar action parity.** All five paired actions use identical enable conditions: Export (`!canExport`, [StyleSidebarView.swift:194](Sources/StoryStamper/Views/StyleSidebarView.swift:194) / [StoryCommands.swift:35](Sources/StoryStamper/Views/StoryCommands.swift:35)), Add (`!canAddBlock`, 59/41), Remove (`blocks.count < 2`, 64/48), Play and Unload (`video == nil`, StoryCommands 63/68). No drift. This is the single most common place for menu-bar apps to rot, and it is clean.

**F4 (Reviewed, clean) — Keyboard shortcut hygiene.** Two documented collision fixes: Remove Text Block moved off ⌘⌫ because it is delete-to-line-start in text fields ([StoryCommands.swift:43-45](Sources/StoryStamper/Views/StoryCommands.swift:43)); Area Guides moved off ⌘G because that is Find Next ([StoryCommands.swift:72](Sources/StoryStamper/Views/StoryCommands.swift:72)). Play/Pause deliberately has **no** menu shortcut so the transport bar can surrender the space bar while the text field has focus ([StoryCommands.swift:59-61](Sources/StoryStamper/Views/StoryCommands.swift:59), [VideoPreviewView.swift:334-338](Sources/StoryStamper/Views/VideoPreviewView.swift:334)). This is careful work.

**F5 (Reviewed, clean) — Export safety.** Staged encode in scratch, promoted only on clean exit ([VideoExporter.swift:8-12, 74-75](Sources/StoryStamper/Export/VideoExporter.swift:8)); source-overwrite guard (line 21); cancellation re-checked across the gap before the move. Save-panel overwrite confirmation is the system's, correctly not duplicated (line 78).

---

## 9. State-Handling Findings

**ST1 (Medium) — No announcement when async work finishes.** An export completing swaps `ExportProgressView` for the completed branch ([ExportStatusView.swift:21-36](Sources/StoryStamper/Views/ExportStatusView.swift:21)); a failure replaces the whole sheet with `FailureSheet` ([MainWindowView.swift:40-44](Sources/StoryStamper/Views/MainWindowView.swift:40)). Neither posts an accessibility notification. `ProgressView` at [ExportStatusView.swift:63](Sources/StoryStamper/Views/ExportStatusView.swift:63) carries no `accessibilityLabel` or `accessibilityValue`, so its spoken value is whatever SwiftUI infers.

**Why it matters:** the export is the app's one long-running operation and its two outcomes are exactly what a non-sighted user needs told. **Recommendation:** label the `ProgressView` (*"Export progress"*, value from the same `statusLine` string so spoken and visible cannot diverge — the pattern `SliderRow` already uses at [SliderRow.swift:32-33](Sources/StoryStamper/Views/Components/SliderRow.swift:32)), and post an `NSAccessibility` announcement on transition to `.completed` and on `failure` being set.

**ST2 (Low) — Drop-target state is visual only.** `isDropTargeted` draws an accent ring ([VideoPreviewView.swift:29-35](Sources/StoryStamper/Views/VideoPreviewView.swift:29)) with no accessibility signal. Low impact — drag-and-drop is inherently pointer-driven, and the `Open Video…` path is fully keyboard-reachable.

**ST3 (Reviewed, clean) — State coverage is genuinely complete.** Empty, loading (superseded-load cancellation at [StoryProject.swift:453-468](Sources/StoryStamper/State/StoryProject.swift:453)), populated, disabled, exporting, complete, and eight distinct failure causes all have defined presentations. `ExportPhase` deliberately carries no failure case ([ExportPhase.swift:5-6](Sources/StoryStamper/Models/ExportPhase.swift:5)) so failures have one home. Stale-index safety via `safeSelectedIndex` ([StoryProject.swift:267](Sources/StoryStamper/State/StoryProject.swift:267)). Lenient settings decoding so an older install degrades rather than resets ([OverlayStyle.swift:139-152](Sources/StoryStamper/Models/OverlayStyle.swift:139)). Sidebar width clamped on read *and* write ([SettingsStore.swift:45-52](Sources/StoryStamper/Support/SettingsStore.swift:45)). I looked for missing states and did not find one.

---

## 10. User / Role / Permission Findings

**Not applicable.** No authentication, accounts, roles, permissions, plans, or account states — and their absence is a stated product rule ([AGENTS.md](AGENTS.md): *"no accounts, analytics, cloud calls…"*), reinforced in [AboutView.swift:29](Sources/StoryStamper/Views/AboutView.swift:29). The app performs no network I/O; the only outbound action is `NSWorkspace.open` on the repository URL from Help and About. Nothing to audit, and nothing missing.

---

## 11. Cross-Surface Findings

Two surfaces share code: the GUI and the `--smoke-export` CLI.

**X1 (Low) — Dimensions and frame rate are formatted three ways, with no shared helper.**

| Surface | Dimensions | Frame rate |
| --- | --- | --- |
| Sidebar | `1080 × 1920` (U+00D7, spaced) — [SourceSidebarView.swift:79](Sources/StoryStamper/Views/SourceSidebarView.swift:79) | `%.5g fps` → `30 fps` — line 83 |
| Settings copy | `1080 × 1920` hardcoded — [SettingsView.swift:23](Sources/StoryStamper/Views/SettingsView.swift:23) | — |
| CLI | `1080x1920` (ASCII x) — [SmokeTest.swift:32, 35, 52](Sources/StoryStamper/SmokeTest.swift:32) | raw `Float` → `30.0 fps` — line 32 |

**What it conflicts with:** the app already proves it knows better. [VideoInfo.swift:21-23](Sources/StoryStamper/Models/VideoInfo.swift:21) centralizes time formatting with an explicit rationale — *"The one place playback time is formatted, so the sidebar and the transport bar can never disagree about what 90 seconds looks like."* Dimensions and frame rate get no such treatment despite appearing in as many places.

**Nuance:** ASCII `x` in terminal output is defensible. The **frame-rate** difference is not — `30` vs `30.0` for the same file is drift, not platform convention. **Recommendation:** add `VideoInfo.dimensionsText` and `VideoInfo.frameRateText` beside `timecode`; let the CLI substitute ASCII `x` if you prefer, but from one source.

**X2 (Low) — Undocumented CLI flag.** `--source-resolution` is read at [SmokeTest.swift:23](Sources/StoryStamper/SmokeTest.swift:23) but appears in neither the usage string (line 15) nor the doc comment (line 5) nor [AGENTS.md](AGENTS.md) nor DEVELOPING.md's command list. The usage string also disagrees with the doc comment on argument presentation (`input output [text]` vs `input.mp4 output.mp4 ["story text"]`). **Recommendation:** one line in the usage string.

---

## 12. Accessibility Findings

The baseline is better than most: icon-only controls **cannot be constructed without a spoken label** — `IconButton.label` and `GlyphPicker.title` are non-optional ([IconButton.swift:5-8](Sources/StoryStamper/Views/Components/IconButton.swift:5), [GlyphPicker.swift:14-15](Sources/StoryStamper/Views/Components/GlyphPicker.swift:14)), a genuinely good structural choice. Decorative imagery is hidden consistently (7 sites). Selection state is exposed via `.isSelected` traits on blocks and swatches. `GlyphPicker` is fully keyboard- and VoiceOver-operable.

**A1 (Medium) — `hoverLabel` carries information the accessibility layer never gets, at two sites.** Where both are present the app pairs them so sighted-hover and spoken text match — [IconButton.swift:51-52](Sources/StoryStamper/Views/Components/IconButton.swift:51), [StyleSidebarView.swift:175-176](Sources/StoryStamper/Views/StyleSidebarView.swift:175). Two sites break that:

- [SourceSidebarView.swift:53](Sources/StoryStamper/Views/SourceSidebarView.swift:53) — the filename `Text` has `.hoverLabel(video.url.path)` and no accessibility label. The name is middle-truncated to one line, so VoiceOver reads a **truncated** filename while hover reveals the full path. The information exists and is withheld.
- [ColorRow.swift:33](Sources/StoryStamper/Views/Components/ColorRow.swift:33) — the `ColorPicker`'s accessible name is `"Custom color"` (line 23), but its hover label is an instruction: *"Changes apply as you pick; close the panel when you are done."* That instruction exists because the macOS color panel has no OK button — precisely the confusion a non-sighted user is **most** likely to hit, and they never receive it.

**Note:** the swatch buttons dropped their hover label during this audit, with a documented rationale ([ColorRow.swift:6-9, 71-72](Sources/StoryStamper/Views/Components/ColorRow.swift:6)) — the swatch already shows its color, so naming it repeated the control. They retain `.accessibilityLabel(preset.name)`, which is the right split: the spoken label is the one a non-sighted user cannot get from the pixels. That reasoning is exactly what the two sites above are missing.

**Recommendation:** add `.accessibilityLabel(video.filename)` plus `.accessibilityValue(video.url.path)` at the first; add `.accessibilityHint(…)` carrying the same sentence at the second. Then make it a rule: `hoverLabel` implies an accessibility equivalent.

**A2 (Medium) — Sidebar splitter is mouse-only.** See M6.

**A3 (Medium) — No async-completion announcements.** See ST1.

**A4 (Low) — Video metadata line reads poorly aloud.** [SourceSidebarView.swift:77-86](Sources/StoryStamper/Views/SourceSidebarView.swift:77) produces `1080 × 1920 · 0:15 · 30 fps`. VoiceOver renders `×` as "times" and `·` unpredictably. **Recommendation:** an `.accessibilityLabel` spelling it out — *"1080 by 1920, 15 seconds, 30 frames per second"*.

**A5 (Low) — No reduced-motion handling.** Five animation sites ([VideoPreviewView.swift:282-283](Sources/StoryStamper/Views/VideoPreviewView.swift:282), [HoverLabel.swift:51, 57](Sources/StoryStamper/Views/Components/HoverLabel.swift:51), [ExportStatusView.swift:68](Sources/StoryStamper/Views/ExportStatusView.swift:68)); no `accessibilityReduceMotion` check anywhere. **Nuance:** every duration is ≤ 0.6 s and all are opacity or progress interpolation — no motion, no parallax, nothing vestibular. The honest assessment is that this is **near-zero real impact**, listed for completeness rather than as a defect.

**A6 (Uncertain) — Contrast.** `Opacity.wash` (0.25) black over arbitrary video for the safe-area zones, and `.tertiary` on the version label, are the two places contrast could fall short. Not verifiable from source — see §19.

---

## 13. Implementation / Architecture Causes

**I1 (High — RESOLVED during this audit).** When the sweep began, `GlyphPicker` carried a debug `PROBE` statement writing to stderr on every appearance, containing the codebase's only force unwrap (`.data(using: .utf8)!`) — against an explicit rule in both AGENTS.md and DEVELOPING.md — and splitting an accessibility modifier chain with an unrelated `.background`.

It has since been replaced by the measured-caption implementation now at [GlyphPicker.swift:57-84](Sources/StoryStamper/Views/Components/GlyphPicker.swift:57) and the `CaptionWidth` cache at [GlyphPicker.swift:142-158](Sources/StoryStamper/Views/Components/GlyphPicker.swift:142). Re-verified: **no `PROBE`, no `standardError.write`, and no force unwrap anywhere in `Sources/`.**

**Residual recommendation:** the episode is a decent argument for a cheap backstop — `check-style.sh` already gates `Views/` on raw literals and could grep for `PROBE` / `FileHandle.standardError` / `!` -force-unwrap in the same pass for near-zero cost. Nothing else to do here.

**I2 (Medium) — Two alphas for one described job.** [DesignSystem.swift:80-81](Sources/StoryStamper/DesignSystem/DesignSystem.swift:80) defines `Opacity.scrim = 0.5` as *"Dark backing behind a control, **or a drop shadow, over video**."* [OverlayRenderer.swift:90](Sources/StoryStamper/Rendering/OverlayRenderer.swift:90) draws a drop shadow over video at a raw `0.45`. Same job by the token's own definition, two values, four hundredths apart — the textbook near-miss.

Line 91 adds `shadowBlurRadius = style.fontSize * 0.1`, a second unnamed constant. Both sit in a file that otherwise names its constants meticulously (`bleed`, `cornerRadiusRatio`, `minCornerRadius`, `maxCornerRadius` — [OverlayRenderer.swift:18-24](Sources/StoryStamper/Rendering/OverlayRenderer.swift:18)), including one carrying an explicit note about *not* borrowing from `Radius` (line 21).

**Nuance:** these render into the **exported video**, not app chrome, so `check-style.sh` correctly does not scan them, and a shadow tuned against burned-in text may legitimately differ from a UI scrim. **Recommendation:** either name them locally alongside the existing four (`shadowAlpha`, `shadowBlurRatio`), or reference `Opacity.scrim` if 0.5 is acceptable. Naming them locally is the smaller change and matches the file's own habit. **Systemic (S4).**

**I3 (Low) — `Metrics.sheetTextWidth` and `Metrics.progressWidth` are both 280.** [DesignSystem.swift:219-220](Sources/StoryStamper/DesignSystem/DesignSystem.swift:219). `Opacity` explicitly documents that coincident values must not be collapsed (lines 77-78); `Metrics` carries no such note. **Assessment: intentional and correct** — a paragraph measure and a progress-bar width are independent. Listed only to suggest extending `Opacity`'s disclaimer to `Metrics` so a future reader doesn't "helpfully" merge them.

**I4 (Reviewed, clean) — Concurrency and lifecycle.** `isolated deinit` with a documented rationale ([StoryProject.swift:120-139](Sources/StoryStamper/State/StoryProject.swift:120)); render coalescing with one in-flight task per block (lines 386-404); undo grouping mirroring the same shape (lines 250-257); `@unchecked Sendable` boxes each carrying a justification ([FFmpegService.swift:3-12](Sources/StoryStamper/Export/FFmpegService.swift:3)); FFmpeg via argument array with no shell ([FFmpegService.swift:50-51](Sources/StoryStamper/Export/FFmpegService.swift:50)). No issues found.

---

## 14. Inferred Design-System Conventions

Reconstructed from the code, not imposed. Where the repo states a rule, I cite it rather than infer.

| Domain | Convention | Status |
| --- | --- | --- |
| Type scale | 10 / 13 / 16 pt only, via `Font.app*` helpers; never SwiftUI semantic styles | **Stated + enforced.** Verified: zero violations |
| Icon scale | Separate from type; `.font(.system(size:))` on `Image` only, never `Text` | **Stated + enforced.** Verified: 6/6 correct |
| Spacing | 4-pt grid, 2–24; `spacing: 0` the sole sanctioned literal | **Stated + enforced.** Passing |
| Radii / borders | `Radius` 6/12; `BorderWidth` 1/2/3 | **Stated + enforced** |
| Alpha | Named in `Opacity`; deliberately not deduplicated | **Stated + enforced in `Views/`.** Gap outside it (I2) |
| Motion | Named in `Motion`; ≤ 0.75 s; `.easeOut` for UI, `.linear` for progress | **Consistent** |
| **Color** | — | **No convention.** System semantics plus one-off `.orange`/`.green` (S1) |
| **Emphasis ramp** | `.secondary` for hints; `.tertiary` once | **Convention by habit only** (S1) |
| Focus | Self-drawn controls get `.focusEffectDisabled()` + `focusHalo`; halo outside, selection inside, never the same reading | **Stated + followed** 4/5 (M6 the exception) |
| Tooltips | App-drawn `hoverLabel` at 0.25 s; `.help()` banned | **Stated + enforced.** Verified: zero `.help()` |
| Icon-only controls | Spoken label structurally required | **Stated + enforced by type system** |
| Component reuse | Check `Views/Components` before building a control | **Stated + followed.** No forks found |
| Sheets | *(two archetypes, no primitive)* | **No convention** (S2) |
| Copy — labels | Title Case | Followed, 1 exception (M9) |
| Copy — prose | Sentence case, lowercase nouns | Followed, 1 exception (M3) |
| Copy — failure titles | Title Case in practice; docs say sentence case | **Contradictory** (M10) |
| Copy — punctuation | Oxford comma; em-dash unspaced | **Stated.** 1 violation (M4) |
| **Copy — action verbs** | — | **No convention** (S3) |
| Dialog commands | *(should take `…`)* | **Absent** (H3) |
| Formatting | Time centralized; dimensions and frame rate not | **Partial** (X1) |

The pattern is stark and worth stating plainly: **every convention that has a written home and a script behind it holds. Every convention that lives only in the authors' heads has drifted.** That is not a criticism of judgment — it is an argument for where to spend the next hour.

---

## 15. Recommended Standardization Work

Ordered by payoff.

1. **Fix the action vocabulary** (S3 → H1, H2, H6, F1). Write the table below into DEVELOPING.md, then make the code match. One concept, one verb, everywhere it appears.

   | Concept | Menu | Button | Undo name | A11y |
   | --- | --- | --- | --- | --- |
   | Load | `Open Video…` / `Replace Video…` | same | — | same |
   | Discard | `Unload Video` | `Unload Video` | `Unload Video` | same |
   | Add block | `Add Text Block` | `Add Text Block` | `Add Text Block` | same |
   | Remove block | `Remove Text Block` | `Remove Text Block` | `Remove Text Block` | same |
   | Export | `Export Video…` | `Export Video` | — | same |

2. **Add the missing token groups** (S1). A `Palette`/`Status` group for success, warning, and the muted ramp; extend `check-style.sh` to flag bare `.orange`/`.green`/`.red` in `Views/`. Closes the one unenforced half of the system.

3. **Build a `Sheet` container** (S2 → M1, M2, V2). Title, body, footer buttons; owns width, padding, base font, title token, and button placement. Migrate all four sheets.

4. **Add `…` to dialog-opening commands** (H3). Mechanical.

5. **Bring `SidebarSplitter` up to `GlyphPicker`'s standard** (M6/A2).

6. **Centralize dimension and frame-rate formatting** (X1), beside `VideoInfo.timecode`.

7. **Decide the failure-title case rule and fix the three doc comments** (M10).

---

## 16. Quick Wins

Each is one line or a few, low risk, no design decision required.

| # | Fix | Location |
| --- | --- | --- |
| 1 | ~~Remove the `PROBE` debug write~~ — **done during audit** | [GlyphPicker.swift](Sources/StoryStamper/Views/Components/GlyphPicker.swift) |
| 2 | Undo name `"Clear Video"` → `"Unload Video"` | [StoryProject.swift:492](Sources/StoryStamper/State/StoryProject.swift:492) |
| 3 | Quit prompt: gate on `hasStoryText`, not `video != nil` | [StoryStamperApp.swift:124](Sources/StoryStamper/StoryStamperApp.swift:124) |
| 4 | Em-dash spacing in the progress line | [ExportStatusView.swift:95](Sources/StoryStamper/Views/ExportStatusView.swift:95) |
| 5 | `"Export size"` → `"Export Size"` | [SettingsView.swift:18](Sources/StoryStamper/Views/SettingsView.swift:18) |
| 6 | `"…selected Text Block."` → `"…selected text block."` | [StyleSidebarView.swift:109](Sources/StoryStamper/Views/StyleSidebarView.swift:109) |
| 7 | `"story"` → `"Story"` (2 sites, one self-contradicting) | [SettingsView.swift:23](Sources/StoryStamper/Views/SettingsView.swift:23), [SourceSidebarView.swift:91](Sources/StoryStamper/Views/SourceSidebarView.swift:91) |
| 8 | `"cancelled"` → `"canceled"` | [StoryStamperApp.swift:118](Sources/StoryStamper/StoryStamperApp.swift:118) |
| 9 | `"Remove"` → `"Remove Text Block"` | [StyleSidebarView.swift:61](Sources/StoryStamper/Views/StyleSidebarView.swift:61) |
| 10 | `FailureSheet` `"Close"` → `"Done"` | [FailureSheet.swift:28](Sources/StoryStamper/Views/FailureSheet.swift:28) |
| 11 | Sentence-case → Title Case in three doc comments | StoryFailure:11, VideoInfo:50, ExportError:33 |
| 12 | Interpolate `AppInfo.displayName` in two menu strings | [StoryCommands.swift:15, 85](Sources/StoryStamper/Views/StoryCommands.swift:15) |
| 13 | Document `--source-resolution` in the usage string | [SmokeTest.swift:15](Sources/StoryStamper/SmokeTest.swift:15) |
| 14 | Accessibility label + value on the filename row | [SourceSidebarView.swift:53](Sources/StoryStamper/Views/SourceSidebarView.swift:53) |
| 15 | Accessibility hint on the custom `ColorPicker` | [ColorRow.swift:29](Sources/StoryStamper/Views/Components/ColorRow.swift:29) |
| 16 | Name the two shadow constants | [OverlayRenderer.swift:90-91](Sources/StoryStamper/Rendering/OverlayRenderer.swift:90) |
| 17 | Drop the one-off top padding | [AboutView.swift:44](Sources/StoryStamper/Views/AboutView.swift:44) |
| 18 | Rename `SliderRow.help` | [SliderRow.swift:16](Sources/StoryStamper/Views/Components/SliderRow.swift:16) |

---

## 17. Larger Refactors

**R1 — `Sheet` container component.** ~1 new file, 4 migrations. Resolves M1, M2, V2 and prevents the fifth sheet from inventing a third archetype. Requires one decision: `.appTitle` or `.appRegularBold` for sheet titles.

**R2 — Color and emphasis tokens + checker extension.** ~30 lines of tokens, ~5 of shell. Resolves S1, C1, L4.

**R3 — Vocabulary pass.** Touches ~12 strings across 5 files, plus a DEVELOPING.md table. Low technical risk, entirely a naming decision.

**R4 — `SidebarSplitter` keyboard support.** Focusable, halo, arrow-key stepping, `accessibilityAdjustableAction`. Mirrors `GlyphPicker` closely enough to copy its shape.

**Explicitly not recommended:** abstracting the four status icons into a component (C1) — four call sites with genuinely different sizes and colors do not justify a primitive, and [DEVELOPING.md](DEVELOPING.md) rule zero rightly outranks tidiness. Same verdict on merging `sheetTextWidth`/`progressWidth` (I3): coincident values, independent jobs.

---

## 18. Areas Reviewed With No Significant Problems

- **Numeric token conformance in `Views/`.** Checker passes; independently verified by grep. Zero raw geometry, alpha, motion, or stroke literals beyond the two sanctioned forms.
- **Typography discipline.** No SwiftUI semantic font styles anywhere; `.font(.system(size:))` on `Image` only, 6/6.
- **Component layer.** No forked, duplicated, or near-identical components. Nine components, each with one implementation and a documented reason to exist.
- **Menu/sidebar action parity.** All five paired actions share enable conditions exactly.
- **Keyboard shortcut hygiene.** Two documented system-collision fixes; one deliberate shortcut omission with a documented reason.
- **Undo/redo.** Coverage over every structural mutation, coalescing groups, `isRestoring` guard, value-type snapshots. Typing deliberately left to the text editor's own stack.
- **Export safety.** Staging, source-overwrite guard, cancellation checks across the promote gap, scratch sweeping off the critical path.
- **Persistence.** Versioned keys, lenient decoding, clamped on read and write.
- **Concurrency.** Swift 6 clean; every `@unchecked Sendable` and `assumeIsolated` carries a justification.
- **Security.** No shell interpolation; user text reaches FFmpeg only as pixels inside a PNG.
- **Oxford commas.** Compliant throughout.
- **Version consistency.** `AppInfo.developmentVersion`, `CFBundleShortVersionString`, and the CHANGELOG all agree at 1.8.3 — the exact drift the comment at [AppInfo.swift:4-6](Sources/StoryStamper/Support/AppInfo.swift:4) warns about has not occurred. Re-checked after the mid-audit bump from 1.8.2; all three moved together.
- **Decorative-image hiding.** 7/7 correct.
- **Focus-halo semantics.** Revised during the audit to fire on keyboard focus only, suppressing the ring when focus followed a mouse press ([FocusHaloModifier.swift:11-16, 36-49](Sources/StoryStamper/Views/Components/FocusHaloModifier.swift:11)). The fallback is correct-by-default — an unrecognized event shows the halo, so the failure mode is a ring nobody needed rather than a keyboard user with no cursor. This strengthens M6: the splitter is now the only self-drawn control with no focus story at all.

---

## 19. Anything I Could Not Reliably Evaluate

Per [AGENTS.md](AGENTS.md), I did not run, screenshot, or drive the app. These need your eyes — each is a specific place to look, not a general request:

1. **Sheet title weight.** `.appTitle` (16) in About/Settings against `.appRegularBold` (13) in Export/Failure — do they read as the same level of heading? Your answer decides M1.
2. **Safe-area guide contrast.** `Opacity.wash` (0.25 black) over bright footage — are the zones legible without obscuring the frame?
3. **`.tertiary` version label** in the left footer — still readable in both Light and Dark? It is the app's only `.tertiary`.
4. **Drop-prompt rhythm** (V4) — do the four elements at uniform `Spacing.large` read as a group, or does the title/subtitle pair want to be tighter?
5. **`GlyphPicker` captions at the 260 pt sidebar floor** — commit `7fa8c9c` addressed clipping and the uncommitted `PROBE` suggests it is still under investigation. Worth confirming *"Monospace"* and *"System"* fit at minimum width.
6. **Hover-label placement near pane edges** — `HoverLabel` defaults to `.top` with a `.bottom` escape hatch, but only [SourceSidebarView.swift:53](Sources/StoryStamper/Views/SourceSidebarView.swift:53)'s filename row sits near a top edge and it does not pass `.bottom`.
7. **The X button over light footage** — `Opacity.scrim` backing with a white glyph; fine over dark video, unverified over bright.
8. **VoiceOver in practice** — my findings are structural. Actual rotor navigation and announcement order need a real session.
9. **Light/Dark rendering** — no `colorScheme` conditionals exist anywhere, so both modes rest entirely on system semantic colors. That is the right approach; whether every surface lands well in both is unverified.

---

---

## Closing note — what 2.0.0 still needs

Two items are deliberately *not* fixed, because both are yours to decide rather than mine:

**H4 — `NSAlert` for quitting, sheets for everything else.** The constraint is real: `windowShouldClose` must answer synchronously, and a SwiftUI sheet cannot. Keeping the alert is defensible and it is what 1.9.0 does. Replacing it means deferring termination and driving a sheet, which is materially more complex for a visual gain only you can weigh.

**The §19 list.** Nine things needing eyes on a running build. Item 1 was decided for you — sheet titles are now uniformly `.appTitle`, which makes the Export and Failure headings 3 points larger than before. If that reads too heavy for a status sheet, the fix is one line in `SheetChrome.swift`, and the right answer is the one you see.

*Findings: 6 high, 12 medium, 12 low, 4 systemic roots. All but H4 closed in 1.9.0. Build clean, style gate passing, both smoke fixtures green.*
