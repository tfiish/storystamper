import CoreGraphics

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
