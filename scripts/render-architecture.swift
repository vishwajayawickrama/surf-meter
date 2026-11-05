#!/usr/bin/env swift
// Render the proposed component architecture as a 2× PNG and an editable SVG.
// Run from the repository root with the command in docs/diagrams/README.md.
import AppKit
import CoreGraphics
import CoreText
import Foundation

let width = 1280.0, height = 1440.0, scale = 2.0
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let destination = root.appendingPathComponent("docs/diagrams")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.scaleBy(x: scale, y: scale)
context.translateBy(x: 0, y: height)
context.scaleBy(x: 1, y: -1)
context.setAllowsAntialiasing(true)
var svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="1440" viewBox="0 0 1280 1440" role="img" aria-labelledby="title description">
<title id="title">SurfMeter main components</title>
<desc id="description">Safari and Chrome extensions send state through their respective native adapters to a local bridge. Inside the native Mac app, the tracking engine combines browser state, macOS eligibility signals, and preferences. It checkpoints usage through a SwiftData repository, which supplies the SwiftUI menu bar dashboard. Data stays on the Mac.</desc>
<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#7086a5"/></marker></defs>
"""

func color(_ hex: String) -> CGColor {
    let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16)!
    return CGColor(red: CGFloat((value >> 16) & 255) / 255,
                   green: CGFloat((value >> 8) & 255) / 255,
                   blue: CGFloat(value & 255) / 255, alpha: 1)
}
func xml(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double,
         fill: String = "#ffffff", border: String = "#dce4ee", radius: Double = 18) {
    let path = CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                      cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(color(fill))
    context.setStrokeColor(color(border))
    context.setLineWidth(1.4)
    context.drawPath(using: .fillStroke)
    svg += "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"\(radius)\" fill=\"\(fill)\" stroke=\"\(border)\" stroke-width=\"1.4\"/>\n"
}
func text(_ label: String, _ x: Double, _ y: Double, size: Double = 18,
          ink: String = "#23344b", bold: Bool = false, centered: Bool = false) {
    let font = NSFont(name: bold ? "Arial-BoldMT" : "ArialMT", size: size)!
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color(ink))!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attributes))
    let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
    let origin = centered ? x - lineWidth / 2 : x
    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: origin, y: y + size)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
    svg += "<text x=\"\(x)\" y=\"\(y + size)\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"\(size)\" font-weight=\"\(bold ? 700 : 400)\" fill=\"\(ink)\" text-anchor=\"\(centered ? "middle" : "start")\">\(xml(label))</text>\n"
}
func arrow(_ points: [(Double, Double)]) {
    guard let first = points.first, let last = points.last, points.count > 1 else { return }
    context.beginPath()
    context.move(to: CGPoint(x: first.0, y: first.1))
    for point in points.dropFirst() { context.addLine(to: CGPoint(x: point.0, y: point.1)) }
    context.setStrokeColor(color("#7086a5"))
    context.setLineWidth(2)
    context.setLineJoin(.round)
    context.strokePath()
    let previous = points[points.count - 2]
    let angle = atan2(last.1 - previous.1, last.0 - previous.0)
    context.beginPath()
    context.move(to: CGPoint(x: last.0, y: last.1))
    context.addLine(to: CGPoint(x: last.0 - 10 * cos(angle - .pi / 6), y: last.1 - 10 * sin(angle - .pi / 6)))
    context.addLine(to: CGPoint(x: last.0 - 10 * cos(angle + .pi / 6), y: last.1 - 10 * sin(angle + .pi / 6)))
    context.closePath()
    context.setFillColor(color("#7086a5"))
    context.fillPath()
    let data = points.enumerated().map { "\($0.offset == 0 ? "M" : "L") \($0.element.0) \($0.element.1)" }.joined(separator: " ")
    svg += "<path d=\"\(data)\" fill=\"none\" stroke=\"#7086a5\" stroke-width=\"2\" stroke-linejoin=\"round\" marker-end=\"url(#arrow)\"/>\n"
}

// Header and browser boundary.
box(0, 0, width, height, fill: "#f5f8fc", border: "#f5f8fc", radius: 0)
text("SurfMeter", 64, 38, size: 20, ink: "#326df1", bold: true)
text("Main components", 64, 78, size: 36, bold: true)
text("Proposed native architecture · Safari + Chrome · Local data", 64, 131, size: 18, ink: "#64768e")

text("BROWSER EXTENSIONS", 64, 183, size: 14, ink: "#64768e", bold: true)
box(64, 218, 520, 100, fill: "#eaf1ff", border: "#ceddf6")
box(696, 218, 520, 100, fill: "#eaf1ff", border: "#ceddf6")
text("Safari Web Extension", 324, 238, size: 23, bold: true, centered: true)
text("TypeScript · active website / tab / window", 324, 277, size: 17, ink: "#526b8e", centered: true)
text("Chrome extension", 956, 238, size: 23, bold: true, centered: true)
text("TypeScript · active website / tab / window", 956, 277, size: 17, ink: "#526b8e", centered: true)

arrow([(324, 318), (324, 376)])
arrow([(956, 318), (956, 376)])
text("native messaging", 342, 334, size: 15, ink: "#64768e")
text("native messaging", 974, 334, size: 15, ink: "#64768e")
box(64, 376, 520, 100)
box(696, 376, 520, 100)
text("Safari native extension handler", 324, 397, size: 21, bold: true, centered: true)
text("Swift · packaged extension target", 324, 435, size: 17, ink: "#64768e", centered: true)
text("Chrome native messaging host", 956, 397, size: 21, bold: true, centered: true)
text("Swift · registered helper executable", 956, 435, size: 17, ink: "#64768e", centered: true)

// The app is a distinct process boundary; adapters relay to its bridge.
box(64, 552, 1152, 732, fill: "#edf3fc", border: "#c5d6ee", radius: 24)
text("SURFMETER NATIVE APP", 104, 576, size: 15, ink: "#326df1", bold: true)
arrow([(324, 476), (324, 516), (640, 516), (640, 632)])
arrow([(956, 476), (956, 516), (640, 516)])
text("local IPC · validated browser state", 658, 578, size: 15, ink: "#64768e")

box(104, 632, 336, 128)
box(472, 632, 336, 128)
box(840, 632, 336, 128)
text("macOS state observer", 272, 652, size: 21, bold: true, centered: true)
text("AppKit + system APIs", 272, 688, size: 17, ink: "#64768e", centered: true)
text("Foreground · idle · sleep · lock", 272, 721, size: 16, ink: "#64768e", centered: true)
text("Local app bridge", 640, 652, size: 21, bold: true, centered: true)
text("Message validation + connection state", 640, 688, size: 16, ink: "#64768e", centered: true)
text("Current state on reconnect", 640, 721, size: 16, ink: "#64768e", centered: true)
text("User preferences", 1008, 652, size: 21, bold: true, centered: true)
text("UserDefaults / @AppStorage", 1008, 688, size: 17, ink: "#64768e", centered: true)
text("Pause · exclusions · settings", 1008, 721, size: 16, ink: "#64768e", centered: true)

arrow([(272, 760), (272, 807), (448, 807), (448, 850)])
arrow([(640, 760), (640, 850)])
arrow([(1008, 760), (1008, 807), (832, 807), (832, 850)])
text("eligibility", 284, 772, size: 15, ink: "#64768e")
text("browser state", 655, 787, size: 15, ink: "#64768e")
text("rules", 1020, 772, size: 15, ink: "#64768e")
box(350, 850, 580, 150, fill: "#dfeaff", border: "#9fbeee", radius: 20)
text("Activity tracking engine", 640, 872, size: 28, ink: "#244d91", bold: true, centered: true)
text("Swift · one eligible platform at a time", 640, 919, size: 19, ink: "#365f9d", centered: true)
text("Domain grouping · elapsed time · day boundaries", 640, 955, size: 18, ink: "#365f9d", centered: true)

arrow([(448, 1000), (448, 1040), (352, 1040), (352, 1080)])
text("checkpoint usage", 467, 1013, size: 15, ink: "#64768e")
box(104, 1080, 496, 144)
box(680, 1080, 496, 144)
text("Usage repository", 352, 1101, size: 24, bold: true, centered: true)
text("SwiftData · local persistence", 352, 1145, size: 19, ink: "#64768e", centered: true)
text("Daily totals · coverage · retention", 352, 1183, size: 17, ink: "#64768e", centered: true)
text("Menu bar interface", 928, 1101, size: 24, bold: true, centered: true)
text("SwiftUI · MenuBarExtra · Liquid Glass", 928, 1145, size: 18, ink: "#64768e", centered: true)
text("Daily · Yesterday · Weekly · details", 928, 1183, size: 17, ink: "#64768e", centered: true)
arrow([(600, 1152), (680, 1152)])
text("summaries", 640, 1121, size: 12, ink: "#64768e", centered: true)
text("The app owns usage writes. Adapters report state; they do not run another timer.", 104, 1246, size: 16, ink: "#526b8e")

text("LOCAL TO THIS MAC", 64, 1320, size: 14, ink: "#326df1", bold: true)
text("No backend or account. No page content, titles, or full URLs stored.", 64, 1350, size: 19, ink: "#526b8e")
text("Primary state/data flow shown. Native bridge and permissions require Task 1 validation.", 64, 1396, size: 16, ink: "#64768e")
svg += "</svg>\n"
try svg.write(to: destination.appendingPathComponent("components.svg"), atomically: true, encoding: .utf8)
let image = context.makeImage()!
let bitmap = NSBitmapImageRep(cgImage: image)
try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("components.png"))
print("Rendered docs/diagrams/components.png (2560 × 2880) and components.svg")
