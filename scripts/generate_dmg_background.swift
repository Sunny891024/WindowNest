import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: swift generate_dmg_background.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 720, height: 460)

let backgroundColor = NSColor(calibratedWhite: 0.985, alpha: 1.0)
let titleColor = NSColor(calibratedWhite: 0.30, alpha: 1.0)
let subtitleColor = NSColor(calibratedWhite: 0.56, alpha: 1.0)
let hintColor = NSColor(calibratedRed: 0.26, green: 0.62, blue: 0.97, alpha: 1.0)
let footerColor = NSColor(calibratedWhite: 0.68, alpha: 1.0)
let arrowStart = NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 0.95)
let arrowEnd = NSColor(calibratedRed: 0.46, green: 0.74, blue: 0.98, alpha: 0.95)

func paragraphStyle(alignment: NSTextAlignment) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byWordWrapping
    return style
}

func draw(text: String, rect: CGRect, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle(alignment: alignment)
    ]
    text.draw(in: rect, withAttributes: attributes)
}

func roundedSquarePath(rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let image = NSImage(size: canvasSize)
image.lockFocus()

backgroundColor.setFill()
NSRect(origin: .zero, size: canvasSize).fill()

draw(
    text: "WindowNest",
    rect: CGRect(x: 0, y: 330, width: canvasSize.width, height: 48),
    fontSize: 34,
    weight: .semibold,
    color: titleColor,
    alignment: .center
)

draw(
    text: "Drag WindowNest into Applications to install",
    rect: CGRect(x: 0, y: 286, width: canvasSize.width, height: 30),
    fontSize: 20,
    weight: .regular,
    color: subtitleColor,
    alignment: .center
)

let leftTile = CGRect(x: 115, y: 125, width: 136, height: 136)
let rightTile = CGRect(x: 469, y: 125, width: 136, height: 136)

NSColor.white.setFill()
roundedSquarePath(rect: leftTile, radius: 22).fill()
roundedSquarePath(rect: rightTile, radius: 22).fill()

NSColor(calibratedWhite: 0.92, alpha: 1).setStroke()
let leftStroke = roundedSquarePath(rect: leftTile, radius: 22)
leftStroke.lineWidth = 2
leftStroke.stroke()
let rightStroke = roundedSquarePath(rect: rightTile, radius: 22)
rightStroke.lineWidth = 2
rightStroke.stroke()

let arrowPath = NSBezierPath()
arrowPath.move(to: CGPoint(x: 285, y: 190))
arrowPath.line(to: CGPoint(x: 435, y: 190))
arrowPath.line(to: CGPoint(x: 417, y: 205))
arrowPath.move(to: CGPoint(x: 435, y: 190))
arrowPath.line(to: CGPoint(x: 417, y: 175))

let gradient = NSGradient(starting: arrowStart, ending: arrowEnd)
gradient?.draw(in: arrowPath, angle: 0)
arrowEnd.setStroke()
arrowPath.lineWidth = 16
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

draw(
    text: "Drop WindowNest into Applications",
    rect: CGRect(x: 0, y: 72, width: canvasSize.width, height: 24),
    fontSize: 21,
    weight: .medium,
    color: hintColor,
    alignment: .center
)

draw(
    text: "Works on macOS 14 or later",
    rect: CGRect(x: 0, y: 42, width: canvasSize.width, height: 22),
    fontSize: 15,
    weight: .regular,
    color: footerColor,
    alignment: .center
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render DMG background\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outputURL)
