import SwiftUI

// The single source of truth for every number the interface draws with.
// If a view needs a value that is not here, add it here first rather than
// inlining a literal—that is how drift starts. That rule covers color alpha,
// motion, and stroke patterns as much as it covers geometry.

// MARK: - Type

/// The only text sizes allowed in the app. Every entry has a `Font` below it;
/// a size with no font is a size nothing can reach, so the two lists stay
/// exactly in step.
enum TextSize {
    static let small: CGFloat = 10
    static let regular: CGFloat = 13
    static let title: CGFloat = 16
}

extension Font {
    /// Secondary chrome: slider readouts, hints, captions, the version label.
    static let appSmall = Font.system(size: TextSize.small)
    /// Numbers that update in place, so digits keep a constant width.
    static let appSmallDigits = Font.system(size: TextSize.small).monospacedDigit()
    /// Body copy and text input.
    static let appRegular = Font.system(size: TextSize.regular)
    /// Emphasized body copy, such as sheet titles.
    static let appRegularBold = Font.system(size: TextSize.regular, weight: .semibold)
    /// Prominent headings.
    static let appTitle = Font.system(size: TextSize.title, weight: .semibold)
}

// MARK: - Spacing

/// A 4-point grid. All gaps and insets come from here.
enum Spacing {
    static let hair: CGFloat = 2
    static let tight: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}

// MARK: - Shape

enum Radius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 12
}

enum BorderWidth {
    static let hairline: CGFloat = 1
    static let emphasis: CGFloat = 2
    static let strong: CGFloat = 3
}

enum Stroke {
    /// Dash pattern for the selected-block ring.
    static let selectionDash: [CGFloat] = [5, 4]
}

/// The keyboard-focus indicator for controls that draw themselves and so get
/// no system focus ring.
enum FocusHalo {
    static let width: CGFloat = BorderWidth.strong
    /// An optical offset rather than layout: the halo sits outside the
    /// control's own border, so it is not held to the spacing grid.
    static let inset: CGFloat = 5
}

// MARK: - Color alpha

/// Named alpha values. The app draws over video, where a handful of washes and
/// hairlines do all the work; naming them stops four near-identical numbers
/// from accumulating for the same visual job.
///
/// These are independent by design. Where two happen to hold the same number
/// today that is a coincidence, not a duplication—do not collapse them.
enum Opacity {
    /// Dark backing behind a control, or a drop shadow, over video.
    static let scrim: Double = 0.5
    /// Large dimmed region that must stay see-through, such as a safe-area zone.
    static let wash: Double = 0.25
    /// Thin light rule drawn over video.
    static let rule: Double = 0.5
    /// Border on a control sitting against the window background.
    static let border: Double = 0.3
    /// Selection ring around the active block.
    static let ring: Double = 0.8
    /// Halo marking keyboard focus. Deliberately softer than `ring`, so focus
    /// and selection never read as the same thing on the same control.
    static let focusHalo: Double = 0.35
    /// Lift under the selected segment of a glyph picker.
    static let segmentShadow: Double = 0.12
}

// MARK: - Motion

enum Motion {
    /// Guides appearing and disappearing: fast enough to feel instant.
    static let quick: Double = 0.1
    /// How long a burst of edits is gathered before the overlay is redrawn.
    /// Short enough to feel live while typing; long enough that dragging a
    /// slider at 60 Hz does not queue a full-resolution raster per frame.
    static let renderCoalesce: Double = 0.05
    /// How long the pointer must rest on a control before its name appears.
    /// Well under the system tooltip delay, which is not publicly settable—
    /// which is the whole reason these controls draw their own.
    static let tooltipDelay: Double = 0.25
    /// Interpolation between FFmpeg's twice-a-second progress reports.
    static let progress: Double = 0.6
    /// How long a burst of edits of one kind stays a single undo step. Long
    /// enough that one slider drag is one Command-Z; short enough that two
    /// deliberate adjustments are two.
    static let undoCoalesce: Double = 0.75
    /// How often the export sheet's remaining-time estimate is recomputed
    /// between FFmpeg's progress reports.
    static let clock: Double = 1
}

// MARK: - Instagram

/// Numbers that describe Instagram rather than this app: where its interface
/// covers a Story, and what padding it puts around Story text. They live here
/// for the same reason everything else does—so no view carries a raw value—
/// and they are the only entries here that would change because somebody else
/// redesigned something.
enum Instagram {
    /// Fraction of the frame's height that Instagram's own UI covers. Drawn
    /// as guides only, never part of an export.
    static let topSafeFraction: CGFloat = 0.13
    static let bottomSafeFraction: CGFloat = 0.16
    /// Roughly the padding Instagram puts around Story text, in the same
    /// 1080-wide reference units the padding slider uses.
    static let textPadding: Double = 20
}

// MARK: - Icons

/// SF Symbol sizes. Kept separate from `TextSize` because glyphs are balanced
/// optically against their surroundings rather than set on the type scale.
enum IconSize {
    /// A mark drawn inside another control, such as the tick on a swatch.
    static let badge: CGFloat = 9
    /// A letterform specimen inside a segmented control.
    static let sample: CGFloat = 14
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 26
    static let status: CGFloat = 34
    static let emptyState: CGFloat = 44
}

// MARK: - Interaction

/// Gesture tolerances and step sizes. These are hit distances and increments
/// rather than layout, so they are deliberately not held to the 4-point grid.
enum Interaction {
    /// How close, in preview points, a drag must come to a midline before it
    /// snaps. Measured on screen so the feel is the same at any window size.
    static let snapTolerance: CGFloat = 9
    /// Arrow-key step, in normalized video coordinates—roughly 4 px on a
    /// 1080×1920 frame.
    static let nudgeFine: CGFloat = 0.002
    /// Shift-arrow step, for crossing the frame quickly.
    static let nudgeCoarse: CGFloat = 0.02
}

// MARK: - Component sizes

enum Metrics {
    /// The source sidebar is fixed and deliberately narrow: it holds four
    /// lines of metadata and two toggles, and every point it gives up goes to
    /// the preview, which is the thing being judged.
    static let sourceSidebarWidth: CGFloat = 200
    /// The style sidebar is user-resizable within these bounds. Below the
    /// lower bound the slider-plus-readout rows and the padding hint start
    /// wrapping; above the upper bound it is just taking space from the video.
    static let styleSidebarWidth: CGFloat = 300
    static let minStyleSidebarWidth: CGFloat = 260
    static let maxStyleSidebarWidth: CGFloat = 380
    static let styleSidebarRange: ClosedRange<CGFloat> = minStyleSidebarWidth...maxStyleSidebarWidth

    static let minPreviewWidth: CGFloat = 360
    /// Derived, so changing a sidebar or the preview minimum can never leave
    /// the window able to squeeze the preview below its own minimum.
    static let minWindowWidth: CGFloat = sourceSidebarWidth + minStyleSidebarWidth + minPreviewWidth + BorderWidth.hairline * 2
    /// The style sidebar is the taller pane, and this is the height it needs
    /// to show all three sections without scrolling. Only the text editor's
    /// minimum is a number we pick; the rest is the measured height of the
    /// fixed rows and the pinned footer around it. Naming the two separately
    /// means raising the editor's minimum raises the window's too, rather
    /// than silently introducing the scroll 1.3.0 set out to remove.
    static let styleSidebarChromeHeight: CGFloat = 570
    static let minWindowHeight: CGFloat = textEditorMinHeight + styleSidebarChromeHeight
    static let defaultWindowWidth: CGFloat = 1240
    static let defaultWindowHeight: CGFloat = 820

    /// Right-aligned numeric readout beside a slider.
    static let readoutWidth: CGFloat = 32
    /// Color preset swatch diameter.
    static let swatch: CGFloat = 16
    /// Round button floating over the video, and the tap target for any
    /// icon-only button.
    static let overlayButton: CGFloat = 24
    /// One segment of a glyph picker, matching a small segmented control.
    static let segmentHeight: CGFloat = 22
    /// Grab area straddling the sidebar splitter. Wider than the hairline it
    /// sits on, so the drag is reachable without pixel-hunting.
    static let splitterHitWidth: CGFloat = 8
    /// The line under a glyph picker naming the current choice. Fixed, so the
    /// row does not change height as the name changes.
    static let captionHeight: CGFloat = 14
    static let textEditorMinHeight: CGFloat = 100

    static let sheetMinWidth: CGFloat = 340
    static let sheetWidth: CGFloat = 420
    /// Paragraph measure for wrapped body copy inside a sheet.
    static let sheetTextWidth: CGFloat = 280
    static let progressWidth: CGFloat = 280
}
