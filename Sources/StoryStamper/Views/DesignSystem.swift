import SwiftUI

// The single source of truth for every number the interface draws with.
// If a view needs a value that is not here, add it here first rather than
// inlining a literal—that is how drift starts.

// MARK: - Type

/// The only text sizes allowed in the app.
enum TextSize {
    static let micro: CGFloat = 8
    static let small: CGFloat = 10
    static let regular: CGFloat = 13
    static let title: CGFloat = 16
    static let display: CGFloat = 21
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

// MARK: - Icons

/// SF Symbol sizes. Kept separate from `TextSize` because glyphs are balanced
/// optically against their surroundings rather than set on the type scale.
enum IconSize {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 26
    static let status: CGFloat = 34
    static let emptyState: CGFloat = 44
}

// MARK: - Component sizes

enum Metrics {
    static let sidebarWidth: CGFloat = 300
    static let minPreviewWidth: CGFloat = 360
    static let minWindowWidth: CGFloat = 1000
    static let minWindowHeight: CGFloat = 640
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
    static let aboutWidth: CGFloat = 420
    static let progressWidth: CGFloat = 280
}
