#!/usr/bin/env swift
// Generate the component diagram as PNG, SVG, and editable diagrams.net XML.
import AppKit
import CoreGraphics
import CoreText
import Foundation

let width = 1600.0, height = 1020.0, scale = 2.0
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("docs/diagrams")
let iconDirectory = output.appendingPathComponent("icons")
try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
let cg = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale),
                   bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
cg.scaleBy(x: scale, y: scale)
cg.translateBy(x: 0, y: height)
cg.scaleBy(x: 1, y: -1)
var svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1020" viewBox="0 0 1600 1020" role="img" aria-labelledby="title desc">
<title id="title">SurfMeter component architecture</title>
<desc id="desc">Browser extensions send state through separate native adapters into the Mac app. A tracking engine combines browser state, OS eligibility, and preferences. Usage is saved locally and presented through the menu bar interface.</desc>
<defs><marker id="arrow" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 Z" fill="#526171"/></marker></defs>
"""
var cells = ["<mxCell id=\"0\"/>", "<mxCell id=\"1\" parent=\"0\"/>"]
var serial = 1
func nextID() -> String { serial += 1; return "c\(serial)" }
func xml(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
}
func color(_ hex: String) -> CGColor {
    let n = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16)!
    return CGColor(red: CGFloat((n >> 16) & 255)/255, green: CGFloat((n >> 8) & 255)/255,
                   blue: CGFloat(n & 255)/255, alpha: 1)
}
func vertex(_ value: String, _ style: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
    cells.append("<mxCell id=\"\(nextID())\" value=\"\(xml(value))\" style=\"\(xml(style))\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" as=\"geometry\"/></mxCell>")
}
func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double,
          fill: String = "#ffffff", stroke: String = "#a6b0bc", dashed: Bool = false, radius: Double = 0) {
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: CGRect(x:x,y:y,width:w,height:h),cornerWidth:radius,cornerHeight:radius,transform:nil))
    cg.setFillColor(color(fill)); cg.setStrokeColor(color(stroke)); cg.setLineWidth(1.3)
    if dashed { cg.setLineDash(phase: 0, lengths: [7,5]) }
    cg.drawPath(using:.fillStroke); cg.restoreGState()
    svg += "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"\(radius)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"1.3\"\(dashed ? " stroke-dasharray=\"7 5\"" : "")/>\n"
    vertex("", "rounded=\(radius > 0 ? 1:0);arcSize=4;fillColor=\(fill);strokeColor=\(stroke);strokeWidth=1.3;dashed=\(dashed ? 1:0);", x,y,w,h)
}
func label(_ s: String, _ x: Double, _ y: Double, size: Double = 16,
           bold: Bool = false, ink: String = "#293442", center: Bool = false) {
    let font = NSFont(name:bold ? "Helvetica-Bold":"Helvetica",size:size)!
    let attr: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:NSColor(cgColor:color(ink))!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:attr))
    let measured = CTLineGetTypographicBounds(line,nil,nil,nil)
    let left = center ? x-measured/2:x
    cg.saveGState(); cg.textMatrix = .identity
    cg.translateBy(x:left,y:y+size); cg.scaleBy(x:1,y:-1); cg.textPosition = .zero
    CTLineDraw(line,cg); cg.restoreGState()
    svg += "<text x=\"\(x)\" y=\"\(y+size)\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"\(size)\" font-weight=\"\(bold ? 700:400)\" fill=\"\(ink)\" text-anchor=\"\(center ? "middle":"start")\">\(xml(s))</text>\n"
    vertex(s,"text;html=0;align=left;verticalAlign=top;whiteSpace=wrap;overflow=visible;strokeColor=none;fillColor=none;fontFamily=Helvetica;fontSize=\(size);fontColor=\(ink);fontStyle=\(bold ? 1:0);spacing=0;",left,y,measured+3,size+7)
}
func route(_ points: [(Double,Double)], dashed: Bool = false, arrow: Bool = true) {
    cg.saveGState(); cg.setStrokeColor(color("#526171")); cg.setLineWidth(1.5)
    if dashed { cg.setLineDash(phase:0,lengths:[6,4]) }
    cg.beginPath(); cg.move(to:CGPoint(x:points[0].0,y:points[0].1))
    for p in points.dropFirst() { cg.addLine(to:CGPoint(x:p.0,y:p.1)) }
    cg.strokePath(); cg.restoreGState()
    if arrow {
        let end = points.last!, previous = points[points.count-2]
        let a = atan2(end.1-previous.1,end.0-previous.0)
        cg.beginPath(); cg.move(to:CGPoint(x:end.0,y:end.1))
        cg.addLine(to:CGPoint(x:end.0-9*cos(a - .pi / 6),y:end.1-9*sin(a - .pi / 6)))
        cg.addLine(to:CGPoint(x:end.0-9*cos(a + .pi / 6),y:end.1-9*sin(a + .pi / 6)))
        cg.closePath(); cg.setFillColor(color("#526171")); cg.fillPath()
    }
    let path = points.enumerated().map { "\($0.offset == 0 ? "M":"L")\($0.element.0) \($0.element.1)" }.joined(separator:" ")
    svg += "<path d=\"\(path)\" fill=\"none\" stroke=\"#526171\" stroke-width=\"1.5\"\(dashed ? " stroke-dasharray=\"6 4\"":"")\(arrow ? " marker-end=\"url(#arrow)\"":"")/>\n"
    let first=points.first!, last=points.last!
    let bends=points.dropFirst().dropLast().map { "<mxPoint x=\"\($0.0)\" y=\"\($0.1)\"/>" }.joined()
    cells.append("<mxCell id=\"\(nextID())\" style=\"endArrow=\(arrow ? "block":"none");endFill=1;html=1;rounded=0;strokeColor=#526171;strokeWidth=1.5;dashed=\(dashed ? 1:0);\" edge=\"1\" parent=\"1\"><mxGeometry relative=\"1\" as=\"geometry\"><mxPoint x=\"\(first.0)\" y=\"\(first.1)\" as=\"sourcePoint\"/><mxPoint x=\"\(last.0)\" y=\"\(last.1)\" as=\"targetPoint\"/><Array as=\"points\">\(bends)</Array></mxGeometry></mxCell>")
}

// Cached, recognizable icons. Browser icons are extracted from installed vendor apps.
// Other symbols come from Apple's SF Symbols, rendered into independent PNG assets.
let symbols = ["extension":"puzzlepiece.extension", "bridge":"cable.connector", "engine":"cpu",
               "system":"desktopcomputer", "settings":"gearshape", "ui":"macwindow"]
func cachedIcon(_ key: String) throws -> Data {
    let url=iconDirectory.appendingPathComponent("\(key).png")
    if FileManager.default.fileExists(atPath:url.path) { return try Data(contentsOf:url) }
    let image:NSImage
    if key == "safari" || key == "chrome" {
        let app=key == "safari" ? "/Applications/Safari.app":"/Applications/Google Chrome.app"
        guard FileManager.default.fileExists(atPath:app) else { fatalError("Missing cached icon and application: \(app)") }
        let iconFile = key == "safari" ? "AppIconUpdated.icns":"app.icns"
        image=NSImage(contentsOfFile:app+"/Contents/Resources/"+iconFile)!
    } else {
        image=NSImage(systemSymbolName:symbols[key]!,accessibilityDescription:nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:80,weight:.regular)
                .applying(NSImage.SymbolConfiguration(paletteColors:[NSColor(cgColor:color("#44546a"))!])))!
    }
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:160,pixelsHigh:160,bitsPerSample:8,
                                samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
    image.draw(in:NSRect(x:8,y:8,width:144,height:144),from:.zero,operation:.sourceOver,fraction:1)
    NSGraphicsContext.restoreGraphicsState()
    let data=bitmap.representation(using:.png,properties:[:])!
    try data.write(to:url)
    return data
}
func icon(_ key: String, _ x:Double, _ y:Double, size:Double=32) throws {
    let data=try cachedIcon(key)
    let image=NSBitmapImageRep(data:data)!.cgImage!
    cg.saveGState(); cg.translateBy(x:x,y:y+size); cg.scaleBy(x:1,y:-1)
    cg.draw(image,in:CGRect(x:0,y:0,width:size,height:size)); cg.restoreGState()
    let uri="data:image/png;base64,"+data.base64EncodedString()
    svg += "<image x=\"\(x)\" y=\"\(y)\" width=\"\(size)\" height=\"\(size)\" href=\"\(uri)\"/>\n"
    let drawioURI="data:image/png,"+data.base64EncodedString()
    vertex("","shape=image;verticalLabelPosition=bottom;verticalAlign=top;imageAspect=0;aspect=fixed;image=\(drawioURI);",x,y,size,size)
}
func component(_ name:String, _ subtitle:String, _ detail:String,
               _ symbol:String, _ x:Double, _ y:Double, _ w:Double, _ h:Double=130,
               fill:String="#ffffff") throws {
    rect(x,y,w,h,fill:fill,stroke:"#7f8c9c")
    try icon(symbol,x+14,y+15,size:30)
    label(name,x+54,y+17,size:17,bold:true)
    label(subtitle,x+16,y+(h <= 100 ? 51:65),size:14,ink:"#526171")
    if !detail.isEmpty { label(detail,x+16,y+(h <= 100 ? 75:89),size:13,ink:"#667484") }
}
func database(_ x:Double,_ y:Double,_ w:Double,_ h:Double) {
    // Conventional database cylinder, not a generic application box.
    cg.saveGState(); cg.setFillColor(color("#ffffff")); cg.setStrokeColor(color("#7f8c9c")); cg.setLineWidth(1.4)
    let path=CGMutablePath()
    path.move(to:CGPoint(x:x,y:y+18)); path.addCurve(to:CGPoint(x:x+w,y:y+18),control1:CGPoint(x:x,y:y-6),control2:CGPoint(x:x+w,y:y-6))
    path.addLine(to:CGPoint(x:x+w,y:y+h-18)); path.addCurve(to:CGPoint(x:x,y:y+h-18),control1:CGPoint(x:x+w,y:y+h+6),control2:CGPoint(x:x,y:y+h+6))
    path.closeSubpath(); cg.addPath(path); cg.drawPath(using:.fillStroke)
    cg.strokeEllipse(in:CGRect(x:x,y:y,width:w,height:36)); cg.restoreGState()
    svg += "<path d=\"M\(x) \(y+18) C\(x) \(y-6),\(x+w) \(y-6),\(x+w) \(y+18) L\(x+w) \(y+h-18) C\(x+w) \(y+h+6),\(x) \(y+h+6),\(x) \(y+h-18) Z\" fill=\"white\" stroke=\"#7f8c9c\" stroke-width=\"1.4\"/><ellipse cx=\"\(x+w/2)\" cy=\"\(y+18)\" rx=\"\(w/2)\" ry=\"18\" fill=\"none\" stroke=\"#7f8c9c\" stroke-width=\"1.4\"/>\n"
    vertex("","shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=18;fillColor=#ffffff;strokeColor=#7f8c9c;",x,y,w,h)
}

// Document title and host boundary.
rect(0,0,width,height,fill:"#ffffff",stroke:"#ffffff")
label("SurfMeter — component architecture",32,20,size:26,bold:true)
label("Proposed native MVP",1370,29,size:14,ink:"#667484",center:false)
label("Browser integrations and in-process application components",32,61,size:15,ink:"#667484")
rect(24,102,1552,834,fill:"#ffffff",stroke:"#9da8b6",dashed:true)
try icon("system",40,114,size:25)
label("User's Mac",76,115,size:17,bold:true)

// Distinct process boundaries.
rect(46,164,302,674,fill:"#fafbfc",stroke:"#c4cbd4",dashed:true)
label("Browser processes",62,178,size:15,bold:true)
rect(380,164,260,674,fill:"#fafbfc",stroke:"#c4cbd4",dashed:true)
label("Native adapter processes",396,178,size:15,bold:true)
rect(680,164,860,732,fill:"#f9fbfd",stroke:"#6d849e",dashed:true)
label("SurfMeter.app",702,180,size:18,bold:true)
label("Swift / SwiftUI · main app process",702,208,size:13,ink:"#667484")

// Extension components live inside their respective browsers.
for (browser,key,y) in [("Safari","safari",228.0),("Google Chrome","chrome",588.0)] {
    rect(62,y,270,174,stroke:"#9da8b6",radius:3)
    try icon(key,78,y+16,size:40)
    label(browser,130,y+21,size:20,bold:true)
    label("Browser process",130,y+52,size:12,ink:"#667484")
    rect(80,y+96,234,60,fill:"#ffffff",stroke:"#7f8c9c")
    try icon("extension",92,y+111,size:28)
    label("Web Extension",130,y+104,size:15,bold:true)
    label("TypeScript",130,y+128,size:12,ink:"#667484")
}
try component("Safari adapter","Native extension handler","Swift / extension target","extension",400,304,220,100)
try component("Chrome host","Native messaging host","Swift / helper executable","extension",400,664,220,100)
route([(314,354),(400,354)])
route([(314,714),(400,714)])
label("native",357,314,size:11,ink:"#526171",center:true)
label("messaging",357,330,size:11,ink:"#526171",center:true)
label("native",357,674,size:11,ink:"#526171",center:true)
label("messaging",357,690,size:11,ink:"#526171",center:true)

// Native app components. Incoming IPC terminates at the local bridge.
try component("Local bridge","Validate messages","Connection health","bridge",720,382,220)
try component("Tracking engine","Eligibility + elapsed time","Domain grouping / day rollover","engine",1060,382,260,130,fill:"#edf4fc")
try component("System state observer","AppKit / macOS APIs","Foreground · idle · sleep · lock","system",1020,238,300,100)
try component("Menu bar UI","SwiftUI / MenuBarExtra","Daily · Yesterday · Weekly","ui",720,680,260)
database(1060,680,260,130)
label("Usage repository",1190,724,size:18,bold:true,center:true)
label("SwiftData · local store",1190,757,size:14,ink:"#526171",center:true)
label("Totals / coverage / retention",1190,781,size:12,ink:"#667484",center:true)
rect(1360,382,144,130,stroke:"#7f8c9c")
try icon("settings",1413,395,size:34)
label("Preferences",1432,435,size:15,bold:true,center:true)
label("UserDefaults",1432,461,size:12,ink:"#526171",center:true)
label("Pause / exclusions",1432,484,size:12,ink:"#667484",center:true)

route([(620,354),(660,354),(660,414),(720,414)])
route([(620,714),(660,714),(660,478),(720,478)])
label("IPC",688,395,size:11,ink:"#526171",center:true)
label("IPC",688,460,size:11,ink:"#526171",center:true)
route([(940,447),(1060,447)])
label("Browser state",1000,420,size:12,ink:"#526171",center:true)
route([(1190,338),(1190,382)])
label("Eligibility",1202,350,size:11,ink:"#526171")
route([(1360,447),(1320,447)],dashed:true)
route([(1190,512),(1190,680)])
label("Checkpoint usage",1204,586,size:13,ink:"#526171")
route([(1060,745),(980,745)])
label("Summaries",1020,719,size:11,ink:"#526171",center:true)
route([(830,512),(830,680)],dashed:true)
label("Live status",842,586,size:13,ink:"#526171")
route([(980,784),(1000,784),(1000,852),(1432,852),(1432,512)],dashed:true)
label("Update settings",1190,830,size:13,ink:"#526171",center:true)

// Legend and architectural constraints, rather than decorative footer slogans.
route([(48,966),(100,966)])
label("State / usage data",112,954,size:13,ink:"#526171")
route([(300,966),(352,966)],dashed:true)
label("Status / control",364,954,size:13,ink:"#526171")
label("Local storage only · No backend · Main app is the sole usage writer",714,954,size:13,ink:"#526171")

svg += "</svg>\n"
try svg.write(to:output.appendingPathComponent("component-architecture.svg"),atomically:true,encoding:.utf8)
let image=cg.makeImage()!
try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("component-architecture.png"))
let model="<mxfile host=\"app.diagrams.net\" type=\"device\"><diagram id=\"surfmeter-components\" name=\"Component architecture\"><mxGraphModel dx=\"1600\" dy=\"1020\" grid=\"1\" gridSize=\"10\" guides=\"1\" tooltips=\"1\" connect=\"1\" arrows=\"1\" fold=\"1\" page=\"1\" pageScale=\"1\" pageWidth=\"1600\" pageHeight=\"1020\" math=\"0\" shadow=\"0\"><root>\(cells.joined())</root></mxGraphModel></diagram></mxfile>"
try model.write(to:output.appendingPathComponent("component-architecture.drawio"),atomically:true,encoding:.utf8)
print("Rendered PNG (3200 × 2040), SVG, and editable diagrams.net source.")
