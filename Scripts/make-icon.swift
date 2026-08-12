// Renders the app icon into an .iconset directory.
//   swift Scripts/make-icon.swift <output.iconset>
// Pure Core Graphics so it runs as a script with no dependencies. The design
// is drawn in a 1024-point space and scaled to each required size.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let design: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(size: CGFloat) -> CGImage? {
    let pixels = Int(size)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { return nil }

    let scale = size / design
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)

    // Rounded-square body, inset from the canvas the way macOS icons are.
    let body = CGRect(x: 96, y: 96, width: 832, height: 832)
    let bodyPath = roundedPath(body, radius: 186)
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()

    let gradientColors = [color(0x6A2FF0), color(0xC42FA8), color(0xFF7A3D)] as CFArray
    if let gradient = CGGradient(colorsSpace: space, colors: gradientColors, locations: [0, 0.55, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: body.minX, y: body.maxY),
            end: CGPoint(x: body.maxX, y: body.minY),
            options: []
        )
    }
    context.restoreGState()

    // The translucent overlay box the app burns onto video, holding two text
    // lines—one per supported text block.
    let box = CGRect(x: 192, y: 354, width: 640, height: 316)
    context.addPath(roundedPath(box, radius: 60))
    context.setFillColor(color(0xFFFFFF, alpha: 0.24))
    context.fillPath()

    let barHeight: CGFloat = 84
    let widths: [CGFloat] = [484, 352]
    var barY = box.maxY - 52 - barHeight
    context.setFillColor(color(0xFFFFFF))
    for width in widths {
        let bar = CGRect(x: box.midX - width / 2, y: barY, width: width, height: barHeight)
        context.addPath(roundedPath(bar, radius: barHeight / 2))
        context.fillPath()
        barY -= barHeight + 44
    }

    return context.makeImage()
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("Usage: make-icon.swift <output.iconset>\n".utf8))
    exit(2)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// (point size, scale) pairs iconutil expects.
let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (points, scale) in variants {
    let pixels = points * scale
    guard let image = drawIcon(size: CGFloat(pixels)) else {
        FileHandle.standardError.write(Data("Failed to render \(pixels)px icon\n".utf8))
        exit(1)
    }
    let suffix = scale == 1 ? "" : "@\(scale)x"
    let url = outputDirectory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
}
print("Wrote \(variants.count) icon sizes to \(outputDirectory.path)")
