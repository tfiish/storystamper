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

// MARK: - Color alpha

/// Named alpha values. The app draws over video, where a handful of washes and
/// hairlines do all the work; naming them stops four near-identical numbers
/// from accumulating for the same visual job.
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
}

// MARK: - Motion

enum Motion {
    /// Guides appearing and disappearing: fast enough to feel instant.
    static let quick: Double = 0.1
    /// Interpolation between FFmpeg's twice-a-second progress reports.
    static let progress: Double = 0.6
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
    static let styleSidebarChromeHeight: CGFloat = 540
    static let minWindowHeight: CGFloat = textEditorMinHeight + styleSidebarChromeHeight
    static let defaultWindowWidth: CGFloat = 1240
    static let defaultWindowHeight: CGFloat = 820

    /// Right-aligned numeric readout beside a slider.
    static let readoutWidth: CGFloat = 32
    /// Color preset swatch diameter.
    static let swatch: CGFloat = 16
    /// Round button floating over the video.
    static let overlayButton: CGFloat = 24
    static let textEditorMinHeight: CGFloat = 100

    static let sheetMinWidth: CGFloat = 340
    static let sheetWidth: CGFloat = 420
    /// Paragraph measure for wrapped body copy inside a sheet.
    static let sheetTextWidth: CGFloat = 280
    static let progressWidth: CGFloat = 280
}
