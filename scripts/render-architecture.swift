#!/usr/bin/env swift
// Three deliberately different architecture views, with PNG/SVG/draw.io exports.
import AppKit
import CoreGraphics
import CoreText
import Foundation

var width = 1400.0, height = 820.0
let scale = 2.0
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/diagrams")
let iconDirectory = output.appendingPathComponent("icons")
try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
var cg: CGContext!
var svg = ""
var cells: [String] = []
var serial = 1
var pages: [String] = []
var usePlex = false
let fontDirectory = output.appendingPathComponent("fonts")
var plexNames: [String:String] = [:]
for weight in ["Regular", "Medium"] {
    let url = fontDirectory.appendingPathComponent("IBMPlexSans-\(weight).ttf")
    let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)! as! [CTFontDescriptor]
    plexNames[weight] = CTFontDescriptorCopyAttribute(descriptors[0], kCTFontNameAttribute) as? String
    guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) else {
        fatalError("Unable to register bundled font: \(url.path)")
    }
}

func begin(_ title: String, _ w: Double, _ h: Double) {
    width=w; height=h; serial=1
    cg=CGContext(data:nil,width:Int(w*scale),height:Int(h*scale),bitsPerComponent:8,bytesPerRow:0,
                 space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    cg.scaleBy(x:scale,y:scale);cg.translateBy(x:0,y:h);cg.scaleBy(x:1,y:-1)
    cells=["<mxCell id=\"0\"/>","<mxCell id=\"1\" parent=\"0\"/>"]
    svg="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(w)\" height=\"\(h)\" viewBox=\"0 0 \(w) \(h)\" role=\"img\"><title>\(xml(title))</title><defs><marker id=\"arrow\" viewBox=\"0 0 10 10\" refX=\"10\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M0 0 L10 5 L0 10 Z\" fill=\"#526171\"/></marker></defs>"
    if usePlex {
        svg += "<style>"
        for (weight, name) in [(400,"Regular"),(500,"Medium")] {
            let data = try! Data(contentsOf: fontDirectory.appendingPathComponent("IBMPlexSans-\(name).ttf"))
            svg += "@font-face{font-family:'IBM Plex Sans';font-style:normal;font-weight:\(weight);src:url(data:font/ttf;base64,\(data.base64EncodedString())) format('truetype');}"
        }
        svg += "</style>"
    }
    rect(0,0,w,h,fill:"#ffffff",stroke:"#ffffff")
}
func save(_ key: String, _ name: String) throws {
    try (svg+"</svg>\n").write(to:output.appendingPathComponent(key+".svg"),atomically:true,encoding:.utf8)
    let image=cg.makeImage()!
    try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(key+".png"))
    let model="<mxGraphModel grid=\"1\" gridSize=\"10\" guides=\"1\" connect=\"1\" arrows=\"1\" page=\"1\" pageScale=\"1\" pageWidth=\"\(Int(width))\" pageHeight=\"\(Int(height))\" background=\"#ffffff\"><root>\(cells.joined())</root></mxGraphModel>"
    let page="<diagram id=\"\(key)\" name=\"\(xml(name))\">\(model)</diagram>"
    pages.append(page)
    try ("<mxfile host=\"app.diagrams.net\" type=\"device\">"+page+"</mxfile>").write(to:output.appendingPathComponent(key+".drawio"),atomically:true,encoding:.utf8)
    print("Rendered \(key): \(Int(width*scale)) × \(Int(height*scale))")
}

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
    let strong = bold && (!usePlex || size >= 24)
    let fontName = usePlex ? plexNames[strong ? "Medium":"Regular"]! : (bold ? "Helvetica-Bold":"Helvetica")
    let family = usePlex ? "IBM Plex Sans":"Helvetica"
    let weight = usePlex ? (strong ? 500:400):(bold ? 700:400)
    let ink = usePlex && ink == "#667484" ? "#596474":ink
    let font = NSFont(name:fontName,size:size)!
    let attr: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:NSColor(cgColor:color(ink))!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:attr))
    let measured = CTLineGetTypographicBounds(line,nil,nil,nil)
    let left = center ? x-measured/2:x
    cg.saveGState(); cg.textMatrix = .identity
    cg.translateBy(x:left,y:y+size); cg.scaleBy(x:1,y:-1); cg.textPosition = .zero
    CTLineDraw(line,cg); cg.restoreGState()
    svg += "<text x=\"\(x)\" y=\"\(y+size)\" font-family=\"\(family), Arial, sans-serif\" font-size=\"\(size)\" font-weight=\"\(weight)\" fill=\"\(ink)\" text-anchor=\"\(center ? "middle":"start")\">\(xml(s))</text>\n"
    vertex(s,"text;html=0;align=left;verticalAlign=top;whiteSpace=wrap;overflow=visible;strokeColor=none;fillColor=none;fontFamily=\(family);fontSize=\(size);fontColor=\(ink);fontStyle=\(usePlex ? 0:(bold ? 1:0));spacing=0;",left,y,measured+3,size+7)
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
               "system":"desktopcomputer", "settings":"gearshape", "ui":"macwindow", "swift":"swift"]
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
                .applying(NSImage.SymbolConfiguration(paletteColors:[NSColor(cgColor:color(key == "swift" ? "#F05138":"#44546a"))!])))!
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
    if key.hasPrefix("lucide-") {
        try lucideIcon(String(key.dropFirst(7)),x,y,size:size)
        return
    }
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


func title(_ primary: String, _ secondary: String) {
    label(primary,40,25,size:26,bold:true)
    label(secondary,40,65,size:15,ink:"#667484")
}
func tile(_ key:String, _ name:String, _ technology:String, _ x:Double,_ y:Double) throws {
    try icon(key,x,y,size:64)
    label(name,x+32,y+80,size:usePlex ? 18:17,bold:!usePlex,center:true)
    label(technology,x+32,y+108,size:usePlex ? 14:13,ink:"#667484",center:true)
}
func note(_ s:String,_ x:Double,_ y:Double) { label(s,x,y,size:13,ink:"#526171",center:true) }

// A: icon-first reference architecture. White space, short labels, one app group.
usePlex = true
begin("A — SurfMeter reference architecture",1400,820)
title("SurfMeter — reference architecture","A · Icon-led overview · Primary information flows · Proposed native app")
rect(454,128,898,575,fill:"#ffffff",stroke:"#aab6c4")
label("SurfMeter.app",474,143,size:17,bold:true)
label("Native Swift application",474,169,size:13,ink:"#667484")
try tile("safari","Safari","Web Extension",90,210)
try tile("chrome","Chrome","Web Extension",90,460)
try tile("lucide-app-window","Safari adapter","Swift extension handler",270,210)
try tile("lucide-square-terminal","Chrome adapter","Swift native host",270,460)
try tile("lucide-arrow-left-right","Local bridge","Validate + reconnect",520,334)
try tile("lucide-cpu","Tracking engine","Swift · eligible time",800,334)
try tile("lucide-sliders-horizontal","Preferences","Pause + exclusions",800,150)
try tile("lucide-monitor","macOS signals","Focus · idle · lock · sleep",800,526)
// Standard database symbol at the same visual scale as the service icons.
database(1120,200,64,64)
label("Local usage store",1152,280,size:18,bold:false,center:true)
label("Core Data",1152,308,size:13,ink:"#667484",center:true)
try tile("lucide-panel-top","Menu bar UI","SwiftUI · Daily + Weekly",1120,470)
route([(154,242),(270,242)]);note("Native messaging",212,219)
route([(154,492),(270,492)]);note("Native messaging",212,469)
route([(334,242),(414,242),(414,356),(520,356)])
route([(334,492),(414,492),(414,386),(520,386)])
note("Local IPC",468,333);note("Local IPC",468,402)
route([(584,366),(800,366)]);note("Browser state",692,340)
route([(832,280),(832,334)]);label("Rules",846,294,size:13,ink:"#526171")
route([(832,526),(832,474)]);label("Eligibility",846,492,size:13,ink:"#526171")
route([(864,350),(1000,350),(1000,232),(1120,232)]);note("Write totals",1060,210)
route([(1152,338),(1152,470)]);label("Read summaries",1166,368,size:13,ink:"#526171")
route([(864,386),(1000,386),(1000,502),(1120,502)],dashed:true);note("Live status",1060,478)
route([(40,752),(90,752)]);label("State / usage data",104,741,size:13,ink:"#526171")
route([(320,752),(370,752)],dashed:true);label("Live status",384,741,size:13,ink:"#526171")
label("All components run on the user's Mac. No backend or account.",650,741,size:14,ink:"#526171")
label("IPC = local inter-process communication. Exact transport and permissions are subject to feasibility validation.",40,787,size:12,ink:"#667484")
try save("architecture-a-reference","A — Icon-led reference")

usePlex = false

// B: C4 component notation: explicit type, technology, responsibility, scope.
func c4(_ name:String,_ type:String,_ description:[String],_ key:String,
        _ x:Double,_ y:Double,_ w:Double,_ h:Double=140,external:Bool=false) throws {
    let fill=external ? "#777777":"#85bbf0", ink=external ? "#ffffff":"#102a43"
    rect(x,y,w,h,fill:fill,stroke:external ? "#666666":"#5c9dd9")
    try icon(key,x+12,y+12,size:26)
    label(name,x+w/2+10,y+16,size:17,bold:true,ink:ink,center:true)
    label(type,x+w/2,y+50,size:12,ink:ink,center:true)
    for (i,line) in description.enumerated() { label(line,x+w/2,y+78+Double(i)*21,size:13,ink:ink,center:true) }
}
begin("B — SurfMeter C4 component view",1280,1060)
title("SurfMeter — C4 component view","B · Scope: the native Mac application · Supporting native adapters shown outside the boundary")
rect(350,126,890,716,fill:"#ffffff",stroke:"#1168bd",dashed:true)
label("SurfMeter.app",370,138,size:17,bold:true,ink:"#08427b")
label("[Container: Swift / SwiftUI]",370,164,size:12,ink:"#526171")
try c4("Safari adapter","[Container: Swift]",["Receives state from the", "Safari Web Extension"],"safari",40,300,240,140,external:true)
try c4("Chrome adapter","[Container: Swift]",["Native messaging host for", "the Chrome extension"],"chrome",40,570,240,140,external:true)
try c4("Local bridge","[Component: Swift]",["Validates browser messages", "and monitors connections"],"bridge",390,390,250)
try c4("Tracking engine","[Component: Swift]",["Counts eligible intervals", "and classifies domains"],"swift",700,390,250)
try c4("OS observer","[Component: AppKit]",["Reports focus, idle,", "sleep and lock state"],"system",700,190,250)
try c4("Preferences","[Component: UserDefaults]",["Stores pause state", "and excluded sites"],"settings",1010,390,190)
try c4("Menu bar UI","[Component: SwiftUI]",["Presents Daily, Yesterday", "and Weekly summaries"],"ui",390,660,250)
try c4("Usage repository","[Component: Core Data]",["Persists totals and coverage", "and provides summaries"],"extension",700,660,250)
database(1000,890,220,120)
label("Local usage data",1110,930,size:17,bold:true,center:true)
label("[Data store: local Core Data]",1110,960,size:12,ink:"#526171",center:true)
route([(280,370),(320,370),(320,425),(390,425)]);note("State [local IPC]",333,344)
route([(280,640),(320,640),(320,495),(390,495)]);label("State",326,554,size:11,ink:"#526171");label("[local IPC]",326,572,size:11,ink:"#526171")
route([(640,460),(700,460)]);note("Valid state",670,438)
route([(825,330),(825,390)]);label("Eligibility [Swift]",841,350,size:12,ink:"#526171")
route([(1010,460),(950,460)]);note("Rules",980,438)
route([(515,530),(515,660)]);label("Publishes status [Swift]",529,585,size:12,ink:"#526171")
route([(825,530),(825,660)]);label("Records time [Swift]",841,585,size:12,ink:"#526171")
route([(700,730),(640,730)]);note("Totals",670,708)
route([(950,760),(1110,760),(1110,890)]);label("Reads / writes",1124,822,size:12,ink:"#526171")
rect(40,876,22,18,fill:"#85bbf0",stroke:"#5c9dd9");label("Component in the native app",76,875,size:13)
rect(40,910,22,18,fill:"#777777",stroke:"#666666");label("Supporting container",76,909,size:13)
label("Each arrow describes an information flow. All storage is local.",40,965,size:13,ink:"#526171")
label("IPC = inter-process communication. Integrations and the deployment target remain subject to validation.",40,1015,size:12,ink:"#667484")
try save("architecture-b-c4","B — C4 component view")

// C: layered architecture, a dependency view rather than a process deployment map.
begin("C — SurfMeter layered architecture",1280,980)
title("SurfMeter — layered architecture","C · Logical responsibilities · Layers do not represent process or deployment boundaries")
func band(_ y:Double,_ h:Double,_ name:String,_ tech:String,_ fill:String) {
    rect(40,y,1200,h,fill:"#ffffff",stroke:"#aab6c4")
    rect(40,y,190,h,fill:fill,stroke:fill)
    label(name,60,y+45,size:18,bold:true,ink:"#ffffff")
    label(tech,60,y+79,size:13,ink:"#ffffff")
}
band(130,150,"Presentation","SwiftUI", "#203955")
band(330,150,"Application","Swift", "#3b526b")
band(530,170,"Integration + data","macOS / persistence", "#60768d")
try component("Menu bar UI","Daily · Yesterday · Weekly","Platform details + setup","ui",270,155,410,100)
try component("Preferences","Pause + excluded sites","UserDefaults / @AppStorage","settings",790,155,380,100)
try component("Tracking engine","Eligibility, domain grouping, elapsed time and day boundaries", "Coordinates platform state and usage persistence","swift",270,355,900,100)
try component("Browser bridge","Safari handler / Chrome host","Native messaging + local IPC","bridge",270,555,280,120)
try component("System observer","Foreground, idle, lock, sleep","AppKit / macOS APIs","system",600,555,280,120)
database(950,555,250,120)
label("Usage repository",1075,594,size:18,bold:true,center:true)
label("Core Data · local store",1075,628,size:14,ink:"#526171",center:true)
route([(640,280),(640,330)]);label("Commands / queries",654,295,size:12,ink:"#526171")
route([(640,480),(640,530)]);label("Calls platform and persistence interfaces",654,495,size:12,ink:"#526171")
try tile("safari","Safari extension","TypeScript",300,785)
try tile("chrome","Chrome extension","TypeScript",550,785)
route([(332,785),(332,744),(410,744),(410,675)],dashed:true)
route([(582,785),(582,744),(410,744)],dashed:true,arrow:false)
label("Native messaging",605,728,size:13,ink:"#526171")
route([(810,816),(860,816)]);label("Layer dependency / call",874,805,size:13,ink:"#526171")
route([(810,852),(860,852)],dashed:true);label("Incoming browser state",874,841,size:13,ink:"#526171")
label("The app remains the sole writer of usage totals. No backend or account is needed.",40,943,size:13,ink:"#526171")
try save("architecture-c-layered","C — Layered architecture")

try ("<mxfile host=\"app.diagrams.net\" type=\"device\">"+pages.joined()+"</mxfile>").write(to:output.appendingPathComponent("architecture-alternatives.drawio"),atomically:true,encoding:.utf8)
print("Saved a three-page editable diagrams.net document.")

// Render the bundled Lucide SVG primitives directly, keeping the SVG export vector.
// These selected upstream icons use only M/L/H/V paths, rectangles, and lines.
struct LucideShape { let name:String; let attributes:[String:String] }
final class LucideParser: NSObject, XMLParserDelegate {
    var shapes:[LucideShape]=[]
    func parser(_ parser:XMLParser,didStartElement elementName:String,namespaceURI:String?,
                qualifiedName:String?,attributes attributeDict:[String:String]) {
        if ["path","rect","line"].contains(elementName) {
            shapes.append(LucideShape(name:elementName,attributes:attributeDict))
        }
    }
}
func lucidePath(_ d:String) -> CGPath {
    let regex=try! NSRegularExpression(pattern:"[A-Za-z]|[-+]?(?:[0-9]*[.])?[0-9]+")
    let tokens=regex.matches(in:d,range:NSRange(d.startIndex...,in:d)).map { String(d[Range($0.range,in:d)!]) }
    var i=0, command="", current=CGPoint.zero
    let path=CGMutablePath()
    func number() -> Double { defer { i += 1 }; return Double(tokens[i])! }
    while i<tokens.count {
        if tokens[i].first!.isLetter { command=tokens[i];i += 1 }
        let relative=command==command.lowercased()
        switch command.uppercased() {
        case "M", "L":
            let x=number(),y=number()
            let next=CGPoint(x:x+(relative ? current.x:0),y:y+(relative ? current.y:0))
            if command.uppercased()=="M" { path.move(to:next);command=relative ? "l":"L" }
            else { path.addLine(to:next) }
            current=next
        case "H":
            current.x=number()+(relative ? current.x:0);path.addLine(to:current)
        case "V":
            current.y=number()+(relative ? current.y:0);path.addLine(to:current)
        case "Z":path.closeSubpath();command=""
        default:fatalError("Unsupported SVG command in bundled icon: \(command)")
        }
    }
    return path
}
func drawLucide(_ shapes:[LucideShape], in context:CGContext) {
    context.setStrokeColor(color("#344054"));context.setLineWidth(1.5)
    context.setLineCap(.round);context.setLineJoin(.round)
    for shape in shapes {
        let a=shape.attributes
        func n(_ key:String,_ fallback:Double=0) -> Double { Double(a[key] ?? "") ?? fallback }
        switch shape.name {
        case "path":context.addPath(lucidePath(a["d"]!))
        case "rect":context.addPath(CGPath(roundedRect:CGRect(x:n("x"),y:n("y"),width:n("width"),height:n("height")),cornerWidth:n("rx"),cornerHeight:n("ry",n("rx")),transform:nil))
        case "line":context.move(to:CGPoint(x:n("x1"),y:n("y1")));context.addLine(to:CGPoint(x:n("x2"),y:n("y2")))
        default:break
        }
        context.strokePath()
    }
}
func lucideIcon(_ name:String,_ x:Double,_ y:Double,size:Double) throws {
    let source=try String(contentsOf:iconDirectory.appendingPathComponent("lucide/\(name).svg"),encoding:.utf8)
    let parser=XMLParser(data:Data(source.utf8)), delegate=LucideParser()
    parser.delegate=delegate
    guard parser.parse() else { fatalError("Invalid bundled Lucide SVG: \(name)") }
    cg.saveGState();cg.translateBy(x:x+4,y:y+4);cg.scaleBy(x:(size-8)/24,y:(size-8)/24)
    drawLucide(delegate.shapes,in:cg);cg.restoreGState()
    let inner=source.components(separatedBy:">").dropFirst().joined(separator:">").replacingOccurrences(of:"</svg>",with:"")
    svg += "<svg x=\"\(x+4)\" y=\"\(y+4)\" width=\"\(size-8)\" height=\"\(size-8)\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#344054\" stroke-width=\"1.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\">\(inner)</svg>\n"
    let bitmap=CGContext(data:nil,width:160,height:160,bitsPerComponent:8,bytesPerRow:0,
                         space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    bitmap.translateBy(x:0,y:160);bitmap.scaleBy(x:1,y:-1);bitmap.translateBy(x:10,y:10);bitmap.scaleBy(x:140/24,y:140/24)
    drawLucide(delegate.shapes,in:bitmap)
    let data=NSBitmapImageRep(cgImage:bitmap.makeImage()!).representation(using:.png,properties:[:])!
    try data.write(to:iconDirectory.appendingPathComponent("lucide-\(name).png"))
    vertex("","shape=image;imageAspect=0;aspect=fixed;image=data:image/png,\(data.base64EncodedString());",x,y,size,size)
}
