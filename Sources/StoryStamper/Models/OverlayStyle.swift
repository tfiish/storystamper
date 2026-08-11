import AppKit
import SwiftUI

/// A color stored as sRGB components so it can round-trip through Codable,
/// SwiftUI's ColorPicker, and Core Graphics without drift.
struct RGBAColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func nsColor(alpha overrideAlpha: Double? = nil) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: overrideAlpha ?? alpha)
    }
}

enum FontChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case bold
    case regular
    case serif
    case monospaced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bold: return "Bold"
        case .regular: return "Regular"
        case .serif: return "Serif"
        case .monospaced: return "Monospaced"
        }
    }

    func nsFont(size: CGFloat) -> NSFont {
        switch self {
        case .bold:
            return .systemFont(ofSize: size, weight: .heavy)
        case .regular:
            return .systemFont(ofSize: size, weight: .regular)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: .bold)
            if let descriptor = base.fontDescriptor.withDesign(.serif),
               let font = NSFont(descriptor: descriptor, size: size) {
                return font
            }
            return base
        case .monospaced:
            return .monospacedSystemFont(ofSize: size, weight: .medium)
        }
    }
}

enum TextAlignmentChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case center
    case right

    var id: String { rawValue }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    var symbolName: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

enum BackgroundMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case solid
    case semiTransparent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .solid: return "Solid"
        case .semiTransparent: return "Translucent"
        }
    }
}

/// Every presentation setting for the text overlay. Font size and padding are
/// expressed in source-video pixels so the exported result is resolution-exact.
struct OverlayStyle: Codable, Equatable, Sendable {
    var font: FontChoice = .bold
    var fontSize: Double = 72
    var alignment: TextAlignmentChoice = .center
    var textColor: RGBAColor = .white
    var backgroundMode: BackgroundMode = .semiTransparent
    var backgroundColor: RGBAColor = .black
    var backgroundOpacity: Double = 0.55
    var padding: Double = 28

    /// The alpha actually used for the background box in the current mode.
    var effectiveBackgroundAlpha: Double {
        switch backgroundMode {
        case .none: return 0
        case .solid: return 1
        case .semiTransparent: return backgroundOpacity
        }
    }
}
