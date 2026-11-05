#!/usr/bin/env swift
// Build documentation figures: original screenshots plus vector callouts, never AI-retouched UI.
import AppKit
import CoreGraphics
import CoreText
import Foundation

struct Note: Decodable { let rect: [Double]; let title: String; let text: String }
struct Figure: Decodable {
    let name: String; let title: String; let source: String; let kind: String
    let width: Double; let crop: [Double]?; let notes: [Note]
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("docs/media/setup")
let figures = try JSONDecoder().decode([Figure].self, from: Data(contentsOf: output.appendingPathComponent("annotations.json")))
func xml(_ string: String) -> String {
    string.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
}
func color(_ hex: String) -> CGColor {
    let value = UInt32(hex.dropFirst(), radix: 16)!
    return CGColor(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255, alpha: 1)
}
func wrap(_ text: String, width: Double, size: Double) -> [String] {
    let font = NSFont.systemFont(ofSize: size)
    var lines: [String] = [], current = ""
    for word in text.split(separator: " ") {
        let trial = current.isEmpty ? String(word) : current + " " + word
        if !current.isEmpty && (trial as NSString).size(withAttributes: [.font: font]).width > width {
            lines.append(current); current = String(word)
        } else { current = trial }
    }
    if !current.isEmpty { lines.append(current) }
    return lines
}
for figure in figures {
    let source = root.appendingPathComponent(figure.source)
    let data = try Data(contentsOf: source)
    guard let image = NSBitmapImageRep(data: data)?.cgImage else { fatalError("Invalid source: \(figure.source)") }
    let region = figure.crop.map { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) } ?? CGRect(x: 0, y: 0, width: image.width, height: image.height)
    guard region.minX >= 0, region.minY >= 0, region.maxX <= Double(image.width), region.maxY <= Double(image.height), let crop = image.cropping(to: region) else { fatalError("Crop outside source: \(figure.name)") }
    let ratio = figure.width / region.width
    let shot = CGRect(x: 32, y: 126, width: figure.width, height: region.height * ratio)
    let legendX = shot.maxX + 40.0
    let width = legendX + 354
    let lineHeight = 19.0
    let cards = figure.notes.map { note in (note, wrap(note.text, width: 294, size: 13)) }
    let legendHeight = cards.reduce(0.0) { $0 + 49 + Double($1.1.count) * lineHeight + 22 }
    let height = ceil(max(shot.maxY + 70, 126 + legendHeight + 42))
    guard let cg = CGContext(data: nil, width: Int(width * 2), height: Int(height * 2), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Canvas allocation failed") }
    cg.scaleBy(x: 2, y: 2); cg.translateBy(x: 0, y: height); cg.scaleBy(x: 1, y: -1)
    var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\"><title>\(xml(figure.title))</title>"
    func rectangle(_ rect: CGRect, fill: String, stroke: String = "none", radius: Double = 0, lineWidth: Double = 1) {
        cg.saveGState(); cg.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        cg.setFillColor(color(fill)); cg.setLineWidth(lineWidth)
        if stroke == "none" { cg.fillPath() } else { cg.setStrokeColor(color(stroke)); cg.drawPath(using: .fillStroke) }
        cg.restoreGState()
        svg += "<rect x=\"\(rect.minX)\" y=\"\(rect.minY)\" width=\"\(rect.width)\" height=\"\(rect.height)\" rx=\"\(radius)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(lineWidth)\"/>"
    }
    func text(_ string: String, _ x: Double, _ y: Double, size: Double = 13, bold: Bool = false, ink: String = "#253248") {
        let font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(ink))!]))
        cg.saveGState(); cg.textMatrix = .identity; cg.translateBy(x: x, y: y + size); cg.scaleBy(x: 1, y: -1); cg.textPosition = .zero; CTLineDraw(line, cg); cg.restoreGState()
        svg += "<text x=\"\(x)\" y=\"\(y+size)\" font-family=\"-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif\" font-size=\"\(size)\" font-weight=\"\(bold ? 600 : 400)\" fill=\"\(ink)\">\(xml(string))</text>"
    }
    func badge(_ number: Int, _ x: Double, _ y: Double) {
        cg.setFillColor(color("#315FBD")); cg.setStrokeColor(color("#FFFFFF")); cg.setLineWidth(2)
        cg.fillEllipse(in: CGRect(x: x-12, y: y-12, width: 24, height: 24)); cg.strokeEllipse(in: CGRect(x: x-12, y: y-12, width: 24, height: 24))
        svg += "<circle cx=\"\(x)\" cy=\"\(y)\" r=\"12\" fill=\"#315FBD\" stroke=\"white\" stroke-width=\"2\"/>"
        text(String(number), x-3.7, y-8.5, size: 13, bold: true, ink: "#FFFFFF")
    }
    rectangle(CGRect(x: 0, y: 0, width: width, height: height), fill: "#F7F9FC")
    text("SURFMETER / SETUP GUIDE", 32, 24, size: 10, bold: true, ink: "#315FBD")
    text(figure.title, 32, 47, size: 25, bold: true)
    text(figure.kind, 32, 88, size: 11, ink: "#52627A")
    rectangle(shot.insetBy(dx: -1, dy: -1), fill: "#FFFFFF", stroke: "#D8E0EC", radius: 2)
    cg.saveGState(); cg.translateBy(x: shot.minX, y: shot.maxY); cg.scaleBy(x: 1, y: -1); cg.draw(crop, in: CGRect(origin: .zero, size: shot.size)); cg.restoreGState()
    // Source PNG remains unchanged. The SVG clips its presentation without changing its pixels.
    svg += "<defs><clipPath id=\"shot\"><rect x=\"\(shot.minX)\" y=\"\(shot.minY)\" width=\"\(shot.width)\" height=\"\(shot.height)\"/></clipPath></defs><image clip-path=\"url(#shot)\" href=\"data:image/png;base64,\(data.base64EncodedString())\" x=\"\(shot.minX-region.minX*ratio)\" y=\"\(shot.minY-region.minY*ratio)\" width=\"\(Double(image.width)*ratio)\" height=\"\(Double(image.height)*ratio)\"/>"
    var y = 126.0
    for (index, card) in cards.enumerated() {
        let target = CGRect(x: shot.minX+(card.0.rect[0]-region.minX)*ratio, y: shot.minY+(card.0.rect[1]-region.minY)*ratio, width: card.0.rect[2]*ratio, height: card.0.rect[3]*ratio)
        guard shot.insetBy(dx: -1, dy: -1).contains(target) else { fatalError("Annotation outside screenshot: \(figure.name) / \(index+1)") }
        cg.setStrokeColor(color("#315FBD")); cg.setLineWidth(1.8); cg.stroke(target)
        svg += "<rect x=\"\(target.minX)\" y=\"\(target.minY)\" width=\"\(target.width)\" height=\"\(target.height)\" fill=\"none\" stroke=\"#315FBD\" stroke-width=\"1.8\"/>"
        badge(index+1, max(14, target.minX-14), target.minY+1)
        badge(index+1, legendX+12, y+13)
        text(card.0.title, legendX+34, y+3, size: 14, bold: true)
        for (line, string) in card.1.enumerated() { text(string, legendX+34, y+31+Double(line)*lineHeight, ink: "#52627A") }
        y += 49 + Double(card.1.count)*lineHeight+22
    }
    text("Numbered boxes identify the controls; the source screenshot is preserved.", 32, height-32, size: 11, ink: "#52627A")
    try (svg+"</svg>\n").write(to: output.appendingPathComponent(figure.name+".svg"), atomically: true, encoding: .utf8)
    guard let result = cg.makeImage(), let png = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) else { fatalError("PNG export failed") }
    try png.write(to: output.appendingPathComponent(figure.name+"@2x.png"))
    print("Rendered \(figure.name) at \(Int(width*2)) × \(Int(height*2))")
}
