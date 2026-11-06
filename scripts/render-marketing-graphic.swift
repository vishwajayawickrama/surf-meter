#!/usr/bin/env swift
// Compose original native app renders; do not regenerate or retouch the UI.
import AppKit
import CoreGraphics
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("docs/media/marketing")
let width = 2800, height = 2100
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: alpha)
}
var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"2800\" height=\"2100\" viewBox=\"0 0 2800 2100\"><title>SurfMeter — Make time visible</title><defs><filter id=\"shadow\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"150%\"><feDropShadow dx=\"0\" dy=\"22\" stdDeviation=\"28\" flood-opacity=\"0.15\"/></filter></defs><rect width=\"2800\" height=\"2100\" fill=\"#e9e9eb\"/>"
context.setFillColor(color(0xe9e9eb)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, ink: UInt32 = 0x202022) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(ink))!]))
    context.saveGState(); context.translateBy(x: x, y: y + size); context.scaleBy(x: 1, y: -1)
    context.textMatrix = .identity; context.textPosition = .zero; CTLineDraw(line, context); context.restoreGState()
    let safe = value.replacingOccurrences(of: "&", with: "&amp;")
    svg += "<text x=\"\(x)\" y=\"\(y+size)\" font-family=\"-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif\" font-size=\"\(size)\" font-weight=\"\(weight == .bold ? 700 : weight == .semibold ? 600 : 400)\" fill=\"#\(String(format: "%06x", ink))\">\(safe)</text>"
}
// The same Bézier geometry as the app's WaveMark, not a generated logo.
context.saveGState(); context.translateBy(x: 110, y: 70); context.scaleBy(x: 2.2, y: 2.2)
context.setStrokeColor(color(0x1676f3)); context.setLineWidth(2.7); context.setLineCap(.round)
var wave = ""
for y: CGFloat in [16, 20] {
    context.move(to: CGPoint(x: 3,y: y))
    context.addCurve(to: CGPoint(x: 11,y: y-9), control1: CGPoint(x: 6,y: y-7), control2: CGPoint(x: 8,y: y-9))
    context.addCurve(to: CGPoint(x: 17,y: y-2), control1: CGPoint(x: 14,y: y-9), control2: CGPoint(x: 14,y: y-2))
    context.addCurve(to: CGPoint(x: 21,y: y-7), control1: CGPoint(x: 18.5,y: y-2), control2: CGPoint(x: 19.5,y: y-4))
    wave += "M3 \(y) C6 \(y-7) 8 \(y-9) 11 \(y-9) C14 \(y-9) 14 \(y-2) 17 \(y-2) C18.5 \(y-2) 19.5 \(y-4) 21 \(y-7) "
}
context.strokePath(); context.restoreGState()
svg += "<path d=\"\(wave)\" transform=\"translate(110 70) scale(2.2)\" fill=\"none\" stroke=\"#1676f3\" stroke-width=\"2.7\" stroke-linecap=\"round\"/>"
text("SurfMeter", x: 180, y: 75, size: 42, weight: .semibold)
text("Make time visible.", x: 103, y: 177, size: 152, weight: .bold)
text("Browser activity, on your Mac.", x: 110, y: 365, size: 44, ink: 0x6a6a70)

func screenshot(_ name: String, rect: CGRect, radius: CGFloat, id: String) throws {
    let data = try Data(contentsOf: output.appendingPathComponent("sources/" + name))
    let image = NSBitmapImageRep(data: data)!.cgImage!
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState(); context.setShadow(offset: CGSize(width: 0, height: 22), blur: 55, color: color(0x000000, alpha: 0.15))
    context.addPath(path); context.setFillColor(color(0xffffff)); context.fillPath(); context.restoreGState()
    context.saveGState(); context.addPath(path); context.clip()
    context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(origin: .zero, size: rect.size)); context.restoreGState()
    context.addPath(path); context.setStrokeColor(color(0x000000, alpha: 0.10)); context.setLineWidth(1); context.strokePath()
    svg += "<defs><clipPath id=\"\(id)\"><rect x=\"\(rect.minX)\" y=\"\(rect.minY)\" width=\"\(rect.width)\" height=\"\(rect.height)\" rx=\"\(radius)\"/></clipPath></defs><rect x=\"\(rect.minX)\" y=\"\(rect.minY)\" width=\"\(rect.width)\" height=\"\(rect.height)\" rx=\"\(radius)\" fill=\"white\" filter=\"url(#shadow)\"/><image x=\"\(rect.minX)\" y=\"\(rect.minY)\" width=\"\(rect.width)\" height=\"\(rect.height)\" clip-path=\"url(#\(id))\" xlink:href=\"data:image/png;base64,\(data.base64EncodedString())\"/>"
}
text("Desktop", x: 110, y: 504, size: 29, weight: .semibold, ink: 0x6a6a70)
try screenshot("desktop-daily-light-2x.png", rect: CGRect(x: 110, y: 565, width: 2030, height: 1439.45), radius: 25, id: "desktop")
text("Menu bar", x: 2190, y: 695, size: 29, weight: .semibold, ink: 0x6a6a70)
try screenshot("menu-daily-dark-2x.png", rect: CGRect(x: 2190, y: 756, width: 500, height: 982.05), radius: 36, id: "menu")
text("macOS · Chrome · Development alpha", x: 2190, y: 1810, size: 23, ink: 0x6a6a70)
text("Sample activity", x: 2190, y: 1850, size: 23, ink: 0x6a6a70)
// Keep the product views intact. No altered numbers, replacement icons or fabricated UI.
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("surf-meter-product-visual-v2.png"))
svg += "</svg>"
try svg.write(to: output.appendingPathComponent("surf-meter-product-visual-v2.svg"), atomically: true, encoding: .utf8)
print("Rendered 2800×2100 product visual and self-contained SVG from original app captures.")
