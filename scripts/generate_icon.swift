#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outputPNG = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon-1024.png"

func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func drawSFSymbol(
    _ name: String,
    pointSize: CGFloat,
    weight: NSFont.Weight = .bold,
    tint: NSColor,
    center: CGPoint,
    shadowColor: NSColor? = nil,
    shadowBlur: CGFloat = 20
) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        .applying(.init(paletteColors: [tint]))
    guard let tinted = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
        return
    }
    let imgSize = tinted.size
    let targetRect = NSRect(
        x: center.x - imgSize.width / 2,
        y: center.y - imgSize.height / 2,
        width: imgSize.width,
        height: imgSize.height
    )

    if let sc = shadowColor, let ctx = NSGraphicsContext.current?.cgContext {
        ctx.saveGState()
        let shadow = NSShadow()
        shadow.shadowColor = sc
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowBlurRadius = shadowBlur
        shadow.set()
        tinted.draw(in: targetRect)
        ctx.restoreGState()
    } else {
        tinted.draw(in: targetRect)
    }
}

let size: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = nsCtx
let ctx = nsCtx.cgContext

let margin: CGFloat = 100.0
let rect = NSRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let radius: CGFloat = rect.width * 0.225
let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

// Outer drop shadow
ctx.saveGState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.45)
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.shadowBlurRadius = 42
shadow.set()
color(0x000000).setFill()
squircle.fill()
ctx.restoreGState()

// Clip to squircle
ctx.saveGState()
squircle.addClip()

let gradientColors = [color(0x0B0F29).cgColor, color(0x1B1448).cgColor, color(0x090D1E).cgColor] as CFArray
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0.0, 0.55, 1.0]) {
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
}

let glow = color(0x6366F1, alpha: 0.35)
let glowColors = [glow.cgColor, glow.withAlphaComponent(0.0).cgColor] as CFArray
if let radGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(
        radGrad,
        startCenter: CGPoint(x: rect.midX, y: rect.midY),
        startRadius: 10,
        endCenter: CGPoint(x: rect.midX, y: rect.midY),
        endRadius: rect.width * 0.55,
        options: []
    )
}

// Subtle background grid
ctx.setStrokeColor(color(0xFFFFFF, alpha: 0.05).cgColor)
ctx.setLineWidth(2)
for step in stride(from: 160.0, through: 864.0, by: 64.0) {
    ctx.move(to: CGPoint(x: step, y: 100))
    ctx.addLine(to: CGPoint(x: step, y: 924))
    ctx.move(to: CGPoint(x: 100, y: step))
    ctx.addLine(to: CGPoint(x: 924, y: step))
}
ctx.strokePath()

let hub = CGPoint(x: 310, y: 512)
let targets: [(CGPoint, NSColor, String)] = [
    (CGPoint(x: 730, y: 725), color(0x00F0FF), "globe"),
    (CGPoint(x: 760, y: 512), color(0xA855F7), "person.crop.circle.fill"),
    (CGPoint(x: 730, y: 299), color(0xFF3366), "envelope.fill")
]

for (dest, routeColor, symbol) in targets {
    let curve = NSBezierPath()
    curve.move(to: hub)
    curve.curve(
        to: dest,
        controlPoint1: CGPoint(x: hub.x + 180, y: hub.y),
        controlPoint2: CGPoint(x: dest.x - 180, y: dest.y)
    )

    ctx.saveGState()
    let routeGlow = NSShadow()
    routeGlow.shadowColor = routeColor.withAlphaComponent(0.85)
    routeGlow.shadowOffset = .zero
    routeGlow.shadowBlurRadius = 28
    routeGlow.set()
    curve.lineWidth = 22
    curve.lineCapStyle = .round
    routeColor.setStroke()
    curve.stroke()
    ctx.restoreGState()

    curve.lineWidth = 8
    color(0xFFFFFF, alpha: 0.85).setStroke()
    curve.stroke()

    let nodeRect = NSRect(x: dest.x - 62, y: dest.y - 62, width: 124, height: 124)
    let nodePath = NSBezierPath(ovalIn: nodeRect)
    ctx.saveGState()
    let nodeShadow = NSShadow()
    nodeShadow.shadowColor = routeColor.withAlphaComponent(0.7)
    nodeShadow.shadowOffset = .zero
    nodeShadow.shadowBlurRadius = 25
    nodeShadow.set()
    color(0x131836).setFill()
    nodePath.fill()
    ctx.restoreGState()

    nodePath.lineWidth = 8
    routeColor.setStroke()
    nodePath.stroke()

    drawSFSymbol(symbol, pointSize: 52, weight: .bold, tint: .white, center: dest, shadowColor: routeColor, shadowBlur: 14)
}

// Main Source Hub on the left
let hubRect = NSRect(x: hub.x - 92, y: hub.y - 92, width: 184, height: 184)
let hubPath = NSBezierPath(ovalIn: hubRect)
ctx.saveGState()
let hubGlow = NSShadow()
hubGlow.shadowColor = color(0x00F0FF, alpha: 0.8)
hubGlow.shadowOffset = .zero
hubGlow.shadowBlurRadius = 36
hubGlow.set()
color(0x1E293B).setFill()
hubPath.fill()
ctx.restoreGState()

hubPath.lineWidth = 10
color(0x00F0FF).setStroke()
hubPath.stroke()

drawSFSymbol("link", pointSize: 82, weight: .bold, tint: .white, center: hub, shadowColor: color(0x00F0FF), shadowBlur: 18)

// Inner glass border highlight
let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), xRadius: radius - 2, yRadius: radius - 2)
borderPath.lineWidth = 6
NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
borderPath.stroke()

ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()

let outURL = URL(fileURLWithPath: outputPNG)
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
if let png = rep.representation(using: .png, properties: [:]) {
    try png.write(to: outURL)
}
