import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fputs("Usage: swift generate_icon.swift <appiconset-path>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fileManager = FileManager.default

let sizes: [(filename: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let background = NSColor(calibratedWhite: 0.10, alpha: 1.0)
let stroke = NSColor(calibratedWhite: 0.96, alpha: 1.0)
let fill = NSColor(calibratedWhite: 0.96, alpha: 0.14)

func makeImage(size: CGFloat) -> NSImage {
    let canvasSize = NSSize(width: size, height: size)
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    let canvas = NSRect(origin: .zero, size: canvasSize)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = size * 0.06
    let roundedCanvas = canvas.insetBy(dx: inset, dy: inset)
    let outerRadius = size * 0.22
    background.setFill()
    NSBezierPath(roundedRect: roundedCanvas, xRadius: outerRadius, yRadius: outerRadius).fill()

    let lineWidth = max(2, size * 0.044)
    let frontFrame = NSRect(
        x: roundedCanvas.minX + size * 0.18,
        y: roundedCanvas.minY + size * 0.20,
        width: size * 0.42,
        height: size * 0.33
    )
    let backFrame = NSRect(
        x: roundedCanvas.minX + size * 0.34,
        y: roundedCanvas.minY + size * 0.36,
        width: size * 0.42,
        height: size * 0.33
    )

    fill.setFill()
    NSBezierPath(roundedRect: backFrame, xRadius: size * 0.075, yRadius: size * 0.075).fill()

    stroke.setStroke()
    let backPath = NSBezierPath(roundedRect: backFrame, xRadius: size * 0.075, yRadius: size * 0.075)
    backPath.lineWidth = lineWidth
    backPath.stroke()

    let frontPath = NSBezierPath(roundedRect: frontFrame, xRadius: size * 0.075, yRadius: size * 0.075)
    frontPath.lineWidth = lineWidth
    frontPath.stroke()

    let frontBar = NSRect(
        x: frontFrame.minX + lineWidth * 0.7,
        y: frontFrame.maxY - size * 0.082,
        width: frontFrame.width - lineWidth * 1.4,
        height: lineWidth * 0.9
    )
    stroke.setFill()
    NSBezierPath(roundedRect: frontBar, xRadius: lineWidth * 0.45, yRadius: lineWidth * 0.45).fill()

    let backBar = NSRect(
        x: backFrame.minX + lineWidth * 0.7,
        y: backFrame.maxY - size * 0.082,
        width: backFrame.width - lineWidth * 1.4,
        height: lineWidth * 0.9
    )
    NSBezierPath(roundedRect: backBar, xRadius: lineWidth * 0.45, yRadius: lineWidth * 0.45).fill()

    image.unlockFocus()
    return image
}

for icon in sizes {
    let image = makeImage(size: icon.pixels)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("Failed to render \(icon.filename)\n", stderr)
        exit(1)
    }

    let destination = outputDirectory.appendingPathComponent(icon.filename)
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try pngData.write(to: destination)
}
