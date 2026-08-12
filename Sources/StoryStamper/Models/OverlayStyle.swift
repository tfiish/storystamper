import AppKit
import SwiftUI

/// A color stored as sRGB components so it can round-trip through Codable,
/// SwiftUI's ColorPicker, and Core Graphics without drift.
struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    /// The two grays sit at even thirds between black and white (0x55, 0xAA).
    static let darkGray = RGBAColor(red: 1 / 3, green: 1 / 3, blue: 1 / 3, alpha: 1)
    static let lightGray = RGBAColor(red: 2 / 3, green: 2 / 3, blue: 2 / 3, alpha: 1)

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

    /// Rough perceptual luminance, used to pick a mark that stays legible on
    /// top of the color itself.
    var isLight: Bool {
        0.299 * red + 0.587 * green + 0.114 * blue > 0.6
    }

    /// Loose match, since a color that round-trips through NSColor and the
    /// system picker can come back a hair off its original components.
    func matches(_ other: RGBAColor) -> Bool {
        let tolerance = 0.01
        return abs(red - other.red) < tolerance
            && abs(green - other.green) < tolerance
            && abs(blue - other.blue) < tolerance
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
        case .monospaced: return "Monospace"
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

    /// The picker shows only the glyph, so this is what a screen reader reads.
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
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

/// Every presentation setting for the text overlay. Sizes are authored against
/// a 1080-wide frame and scaled to the source video at render time.
struct OverlayStyle: Codable, Hashable, Sendable {
    var font: FontChoice = .bold
    var fontSize: Double = 72
    var alignment: TextAlignmentChoice = .center
    var textColor: RGBAColor = .white
    /// A background at full opacity is what used to be the "solid" mode; off
    /// is what used to be "none".
    var backgroundEnabled: Bool = true
    var backgroundColor: RGBAColor = .black
    /// Opaque black under white text is the pairing that reads on any footage,
    /// so it is what a new install opens on; the slider is there to soften it.
    var backgroundOpacity: Double = 1
    var padding: Double = 20

    init() {}

    /// Decoded leniently so settings saved by an older version keep whatever
    /// still applies instead of resetting wholesale.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = OverlayStyle()
        font = try container.decodeIfPresent(FontChoice.self, forKey: .font) ?? fallback.font
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? fallback.fontSize
        alignment = try container.decodeIfPresent(TextAlignmentChoice.self, forKey: .alignment) ?? fallback.alignment
        textColor = try container.decodeIfPresent(RGBAColor.self, forKey: .textColor) ?? fallback.textColor
        backgroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? fallback.backgroundEnabled
        backgroundColor = try container.decodeIfPresent(RGBAColor.self, forKey: .backgroundColor) ?? fallback.backgroundColor
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? fallback.backgroundOpacity
        padding = try container.decodeIfPresent(Double.self, forKey: .padding) ?? fallback.padding
    }
}

/// One entry in a row of one-click color presets.
struct ColorSwatch: Identifiable, Hashable, Sendable {
    let name: String
    let color: RGBAColor

    var id: String { name }
}

/// Ready-made colors offered as one-click swatches beside the color pickers.
enum ColorPreset {
    static let background: [ColorSwatch] = [
        ColorSwatch(name: "Black", color: .black),
        ColorSwatch(name: "Dark Gray", color: .darkGray),
        ColorSwatch(name: "Light Gray", color: .lightGray),
        ColorSwatch(name: "White", color: .white),
    ]
    static let text: [ColorSwatch] = [
        ColorSwatch(name: "White", color: .white),
        ColorSwatch(name: "Black", color: .black),
    ]
}
