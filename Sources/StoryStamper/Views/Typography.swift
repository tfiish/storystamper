import SwiftUI

/// The app's canonical type scale. These five sizes are the only ones allowed
/// for text; anything else is a mistake. Icon and SF Symbol sizes are chosen
/// optically and are deliberately not covered by this scale.
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
