// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import AppKit

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("Bitmap konnte nicht angelegt werden") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 205, yRadius: 205)
NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.55, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.18, green: 0.25, blue: 0.78, alpha: 1)
])!.draw(in: tile, angle: -55)

NSColor.white.withAlphaComponent(0.96).setStroke()
let screen = NSBezierPath(roundedRect: NSRect(x: 205, y: 270, width: 614, height: 438), xRadius: 58, yRadius: 58)
screen.lineWidth = 46
screen.stroke()

let antenna = NSBezierPath()
antenna.move(to: NSPoint(x: 392, y: 760))
antenna.line(to: NSPoint(x: 512, y: 680))
antenna.line(to: NSPoint(x: 632, y: 760))
antenna.lineWidth = 34
antenna.lineCapStyle = .round
antenna.lineJoinStyle = .round
antenna.stroke()

let bars: [(CGFloat, CGFloat)] = [(605, 92), (520, 164), (435, 236)]
for (y, width) in bars {
    let bar = NSBezierPath()
    bar.move(to: NSPoint(x: 310, y: y))
    bar.line(to: NSPoint(x: 310 + width, y: y))
    bar.lineWidth = 36
    bar.lineCapStyle = .round
    bar.stroke()
}

let arrows = NSBezierPath()
arrows.move(to: NSPoint(x: 705, y: 590))
arrows.line(to: NSPoint(x: 748, y: 632))
arrows.line(to: NSPoint(x: 791, y: 590))
arrows.move(to: NSPoint(x: 705, y: 455))
arrows.line(to: NSPoint(x: 748, y: 413))
arrows.line(to: NSPoint(x: 791, y: 455))
arrows.lineWidth = 32
arrows.lineCapStyle = .round
arrows.lineJoinStyle = .round
arrows.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG konnte nicht erzeugt werden") }
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png")
try data.write(to: output)
