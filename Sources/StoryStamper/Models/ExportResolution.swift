import CoreGraphics

/// What resolution an export is encoded at.
///
/// Instagram serves Stories at 1080 × 1920. Re-encoding a 4K source at 4K
/// therefore spends minutes of the user's time and hundreds of megabytes of
/// their upload on pixels the destination throws away, which is precisely the
/// kind of cost rule zero exists to refuse.
enum ExportResolution: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Match the source exactly.
    case source
    /// Fit to a 1080-wide Story frame. Never upscales.
    case story

    var id: String { rawValue }

    /// The narrow side of a Story frame.
    private static let storyNarrowSide: CGFloat = 1080

    var displayName: String {
        switch self {
        case .source: return "Match the source"
        case .story: return "Story (1080)"
        }
    }

    /// Scales proportionally so the narrow side is 1080, and stops there—a
    /// source already at or below 1080 is left alone rather than blown up.
    /// Both sides are rounded to even numbers, which H.264 requires.
    func outputSize(for source: CGSize) -> CGSize {
        guard case .story = self else { return source }
        let narrow = min(source.width, source.height)
        guard narrow > Self.storyNarrowSide else { return source }
        let factor = Self.storyNarrowSide / narrow
        return CGSize(
            width: (source.width * factor).roundedToEven,
            height: (source.height * factor).roundedToEven
        )
    }
}

private extension CGFloat {
    var roundedToEven: CGFloat {
        Swift.max(2, (self / 2).rounded() * 2)
    }
}
