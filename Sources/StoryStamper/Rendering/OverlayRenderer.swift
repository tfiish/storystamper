import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// A rasterized text block at full source-video resolution.
/// CGImage is immutable, so crossing actor boundaries is safe.
struct RenderedOverlay: @unchecked Sendable {
    let cgImage: CGImage
    /// Size of the block in source-video pixels.
    let pixelSize: CGSize
}

/// A rendered block paired with its normalized center, ready for compositing.
struct PlacedOverlay: Sendable {
    let overlay: RenderedOverlay
    let center: CGPoint
}

/// Renders the story text block with Core Graphics. The preview displays this
/// exact image scaled down, and the exporter composites it at full resolution,
/// so the two cannot drift apart.
enum OverlayRenderer {
    /// The text block may occupy at most this fraction of the video width.
    static let maxWidthFraction: CGFloat = 0.92
    /// Style sizes are authored against a 1080-wide Story frame and scaled to
    /// the real video, so "size 72" looks the same on 1080p and 4K footage
    /// instead of rendering half as large on the latter.
    static let referenceNarrowSide: CGFloat = 1080
    /// Extra transparent margin around the text so glyphs never clip at the
    /// bitmap edge; visually part of the padding.
    private static let bleed: CGFloat = 6
    /// The background box's corner radius tracks its padding, held between
    /// bounds that stop a small box looking like a pill and a large one
    /// looking square. Video pixels, so deliberately not `Radius`.
    private static let cornerRadiusRatio: CGFloat = 0.6
    private static let minCornerRadius: CGFloat = 6
    private static let maxCornerRadius: CGFloat = 24

    // MARK: - Text block

    static func renderBlock(text: String, style: OverlayStyle, videoSize: CGSize) -> RenderedOverlay? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, videoSize.width > 0, videoSize.height > 0 else { return nil }

        let style = scaled(style, for: videoSize)
        let attributed = attributedString(text: text, style: style)
        let inset = contentInset(for: style)
        let maxTextWidth = max(videoSize.width * maxWidthFraction - 2 * inset, style.fontSize)

        let bounds = attributed.boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        )
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        guard textSize.width > 0, textSize.height > 0 else { return nil }

        let blockSize = CGSize(width: textSize.width + 2 * inset, height: textSize.height + 2 * inset)
        guard let context = makeContext(size: blockSize) else { return nil }

        // Flip into a top-left origin so AppKit string drawing lays out naturally.
        context.translateBy(x: 0, y: blockSize.height)
        context.scaleBy(x: 1, y: -1)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previous }

        if style.backgroundEnabled {
            let alpha = style.backgroundOpacity
            let radius = cornerRadius(for: style, blockSize: blockSize)
            let path = NSBezierPath(
                roundedRect: CGRect(origin: .zero, size: blockSize),
                xRadius: radius,
                yRadius: radius
            )
            style.backgroundColor.nsColor(alpha: alpha).setFill()
            path.fill()
        }

        attributed.draw(
            with: CGRect(x: inset, y: inset, width: textSize.width, height: textSize.height),
            options: [.usesLineFragmentOrigin]
        )

        guard let image = context.makeImage() else { return nil }
        return RenderedOverlay(cgImage: image, pixelSize: blockSize)
    }

    static func attributedString(text: String, style: OverlayStyle) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment.nsAlignment
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: style.font.nsFont(size: style.fontSize),
            .foregroundColor: style.textColor.nsColor(alpha: 1),
            .paragraphStyle: paragraph,
        ]

        // Without a background box, a soft shadow keeps text legible on
        // bright footage—mirroring how Instagram treats bare Story text.
        if !style.backgroundEnabled {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = style.fontSize * 0.1
            shadow.shadowOffset = .zero
            attributes[.shadow] = shadow
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: - Placement

    /// Clamps a normalized center so the block stays fully inside the canvas.
    /// Blocks wider or taller than the canvas center themselves on that axis.
    static func clampedCenter(_ center: CGPoint, blockSize: CGSize, videoSize: CGSize) -> CGPoint {
        guard videoSize.width > 0, videoSize.height > 0 else { return center }
        let halfW = blockSize.width / 2 / videoSize.width
        let halfH = blockSize.height / 2 / videoSize.height
        let x = halfW >= 0.5 ? 0.5 : min(max(center.x, halfW), 1 - halfW)
        let y = halfH >= 0.5 ? 0.5 : min(max(center.y, halfH), 1 - halfH)
        return CGPoint(x: x, y: y)
    }

    /// The block's frame in top-left-origin video pixel coordinates.
    static func blockRect(blockSize: CGSize, videoSize: CGSize, normalizedCenter: CGPoint) -> CGRect {
        let center = clampedCenter(normalizedCenter, blockSize: blockSize, videoSize: videoSize)
        return CGRect(
            x: center.x * videoSize.width - blockSize.width / 2,
            y: center.y * videoSize.height - blockSize.height / 2,
            width: blockSize.width,
            height: blockSize.height
        )
    }

    // MARK: - Export canvas

    /// Composites every block onto one transparent canvas at full video size,
    /// ready for FFmpeg to overlay at (0, 0) with no coordinate math on its
    /// side. Blocks draw in array order, so later blocks sit on top.
    static func renderFullCanvas(overlays: [PlacedOverlay], videoSize: CGSize) -> CGImage? {
        guard let context = makeContext(size: videoSize) else { return nil }
        context.interpolationQuality = .high
        for placed in overlays {
            let rect = blockRect(blockSize: placed.overlay.pixelSize, videoSize: videoSize, normalizedCenter: placed.center)
            // Convert the top-left-origin rect into Core Graphics' bottom-left origin.
            let cgRect = CGRect(
                x: rect.minX,
                y: videoSize.height - rect.maxY,
                width: rect.width,
                height: rect.height
            )
            context.draw(placed.overlay.cgImage, in: cgRect)
        }
        return context.makeImage()
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ExportError.overlayRenderFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.overlayRenderFailed
        }
    }

    // MARK: - Private helpers

    /// Converts authored sizes into pixels for this video's resolution.
    private static func scaled(_ style: OverlayStyle, for videoSize: CGSize) -> OverlayStyle {
        let factor = min(videoSize.width, videoSize.height) / referenceNarrowSide
        guard factor > 0, factor != 1 else { return style }
        var result = style
        result.fontSize = style.fontSize * factor
        result.padding = style.padding * factor
        return result
    }

    private static func contentInset(for style: OverlayStyle) -> CGFloat {
        style.backgroundEnabled ? style.padding + bleed : bleed
    }

    private static func cornerRadius(for style: OverlayStyle, blockSize: CGSize) -> CGFloat {
        let base = min(max(style.padding * cornerRadiusRatio, minCornerRadius), maxCornerRadius)
        return min(base, min(blockSize.width, blockSize.height) / 2)
    }

    private static func makeContext(size: CGSize) -> CGContext? {
        let width = Int(ceil(size.width))
        let height = Int(ceil(size.height))
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
