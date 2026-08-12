import SwiftUI

/// What every sheet in the app has in common.
///
/// There are two shapes of sheet here and that is deliberate: About and
/// Settings are documents, read left to right at a fixed measure, while the
/// export and failure sheets are outcomes, centered around an icon and sized
/// to their content. Forcing those into one layout would be uniformity for its
/// own sake.
///
/// What is *not* deliberate is the way they drifted on everything else—base
/// font, padding, and the size of a title. Those live here now, so a fifth
/// sheet cannot invent a third answer to any of them.

/// A sheet's heading. Always `.appTitle`: it is the most prominent text in the
/// sheet, which is what that token is for. `.appRegularBold` used to appear
/// here too, and the two doc comments in DesignSystem.swift both claimed sheet
/// titles—which is exactly how one ended up 3 points smaller than the other.
struct SheetTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.appTitle)
    }
}

extension View {
    /// The frame every sheet sits in: body typography, one padding step, and a
    /// width rule.
    ///
    /// Pass a `width` for a sheet whose measure should not depend on its
    /// content—a document, where a fixed column is what makes it readable.
    /// Omit it for a sheet that should size to what it is saying, which is
    /// every status sheet: "Export Complete" and a 300-character FFmpeg error
    /// have no business being the same width.
    func sheetChrome(width: CGFloat? = nil) -> some View {
        font(.appRegular)
            .padding(Spacing.xLarge)
            .frame(width: width)
            .frame(minWidth: width == nil ? Metrics.sheetMinWidth : nil)
    }
}
