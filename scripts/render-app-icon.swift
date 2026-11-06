import AppKit

let destination = CommandLine.arguments[1]
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 80, y: 80, width: 864, height: 864)
let shape = NSBezierPath(roundedRect: rect, xRadius: 194, yRadius: 194)
NSGradient(starting: NSColor(srgbRed: 0.29, green: 0.57, blue: 0.99, alpha: 1), ending: NSColor(srgbRed: 0.12, green: 0.28, blue: 0.70, alpha: 1))!.draw(in: shape, angle: -80)
NSColor.white.withAlphaComponent(0.92).setStroke()
for offset in [0.0, 160.0] {
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 250, y: 385 + offset))
    wave.curve(to: NSPoint(x: 512, y: 385 + offset), controlPoint1: NSPoint(x: 340, y: 490 + offset), controlPoint2: NSPoint(x: 425, y: 280 + offset))
    wave.curve(to: NSPoint(x: 774, y: 385 + offset), controlPoint1: NSPoint(x: 600, y: 490 + offset), controlPoint2: NSPoint(x: 685, y: 280 + offset))
    wave.lineWidth = 46; wave.lineCapStyle = .round; wave.stroke()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
