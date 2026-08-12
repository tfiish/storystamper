import AppKit
import SwiftUI

/// Specimen letters for the Font picker.
///
/// A segmented picker reduces a `Text` to a plain segment label and applies
/// its own control font, which is why four differently styled `Text("A")`s all
/// came out looking identical. An `Image` survives intact—that is why the
/// alignment glyphs work—so each specimen is rasterized here in the very
/// typeface it selects.
@MainActor
enum FontSample {
    /// Two letters, not one: monospace is a property of advance width rather
    /// than of letterform, and SF Mono's capital A is all but identical to SF
    /// Pro's, so a single "A" cannot show it. Weight carries bold, New York's
    /// serifs carry serif, and the wider advance carries monospaced—which is
    /// the subtlest of the four here, since the pair shares its letterforms
    /// with the regular face. Changing this string is the whole lever.
    static let specimen = "Aa"

    /// Four small bitmaps that never change, held rather than redrawn on every
    /// pass through the sidebar's body.
    private static var cache: [FontChoice: Image] = [:]

    static func image(for choice: FontChoice) -> Image {
        if let cached = cache[choice] { return cached }
        let image = render(choice) ?? Image(systemName: "textformat")
        cache[choice] = image
        return image
    }

    private static func render(_ choice: FontChoice) -> Image? {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: choice.nsFont(size: IconSize.sample),
            .foregroundColor: NSColor.black,
        ]
        let string = NSAttributedString(string: specimen, attributes: attributes)
        let measured = string.size()
        let size = CGSize(width: ceil(measured.width) + 2, height: ceil(measured.height))
        guard size.width > 0, size.height > 0 else { return nil }

        // Drawn at 2x and labelled with the logical size, so the glyph stays
        // crisp on Retina rather than being upscaled from a 1x bitmap.
        let scale = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = size

        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        string.draw(at: CGPoint(x: 1, y: 0))
        NSGraphicsContext.current = previous

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        // Template, so the segmented control tints it on selection exactly the
        // way it tints the alignment symbols.
        image.isTemplate = true
        return Image(nsImage: image)
    }
}
