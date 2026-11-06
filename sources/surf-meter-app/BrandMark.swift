import SwiftUI

/// Vector marks from the approved prototype, drawn at the display's native scale.
struct BrandMark: View {
    let id: String
    let fallback: String
    var body: some View {
        if ["youtube.com", "instagram.com", "reddit.com", "x.com", "github.com"].contains(id) {
            Canvas { context, size in
                context.scaleBy(x: size.width / 24, y: size.height / 24)
                let ink = GraphicsContext.Shading.foreground
                func stroke(_ path: Path) { context.stroke(path, with: ink, style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)) }
                func line(_ points: [CGPoint]) -> Path { Path { p in p.addLines(points) } }
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
                switch id {
                case "youtube.com":
                    context.fill(Path(roundedRect: CGRect(x: 2, y: 5, width: 20, height: 14), cornerRadius: 5), with: ink)
                    var p = line([pt(10,9),pt(16,12),pt(10,15)]); p.closeSubpath(); context.fill(p, with: .color(.white))
                case "instagram.com":
                    stroke(Path(roundedRect: CGRect(x: 3, y: 3, width: 18, height: 18), cornerRadius: 5))
                    stroke(Path(ellipseIn: CGRect(x: 8, y: 8, width: 8, height: 8)))
                    context.fill(Path(ellipseIn: CGRect(x: 16.6, y: 5.6, width: 1.8, height: 1.8)), with: ink)
                case "x.com":
                    stroke(line([pt(4,3),pt(20,21),pt(15,21),pt(3,3),pt(8,3),pt(21,21)])); stroke(line([pt(20,3),pt(4,21)]))
                case "reddit.com":
                    stroke(line([pt(12,7),pt(14,3),pt(19,4)]))
                    stroke(Path(ellipseIn: CGRect(x: 18,y: 2,width: 4,height: 4)))
                    stroke(Path(ellipseIn: CGRect(x: 3,y: 8,width: 18,height: 12)))
                    var p = Path(); p.move(to: pt(4,10)); p.addCurve(to: pt(3,14), control1: pt(0,5), control2: pt(0,14)); p.move(to: pt(20,10)); p.addCurve(to: pt(21,14),control1: pt(24,5),control2: pt(24,14)); p.move(to: pt(8,17)); p.addCurve(to: pt(16,17),control1: pt(10,19),control2: pt(14,19)); stroke(p)
                    for x: CGFloat in [7,15] { context.fill(Path(ellipseIn: CGRect(x: x,y: 12,width: 2,height: 2)),with: ink) }
                default:
                    var p = Path(); p.move(to: pt(8,20)); p.addCurve(to: pt(1,17),control1: pt(3,21),control2: pt(3,17))
                    p.move(to: pt(14,22)); p.addLine(to: pt(14,18)); p.addCurve(to: pt(13.5,16),control1: pt(14,17),control2: pt(14.1,16.4)); p.addCurve(to: pt(19.5,11),control1: pt(17.5,15.5),control2: pt(19.5,14)); p.addCurve(to: pt(18,7.5),control1: pt(19.5,9.5),control2: pt(19,8.5)); p.addCurve(to: pt(18,4),control1: pt(18.3,6.5),control2: pt(18.3,5)); p.addCurve(to: pt(14,5.5),control1: pt(16,4),control2: pt(15,5)); p.addQuadCurve(to: pt(7,5.5),control: pt(10.5,4.5)); p.addCurve(to: pt(3,4),control1: pt(6,5),control2: pt(5,4)); p.addCurve(to: pt(3,7.5),control1: pt(2.7,5),control2: pt(2.7,6.5)); p.addCurve(to: pt(1.5,11),control1: pt(2,8.5),control2: pt(1.5,9.5)); p.addCurve(to: pt(7.5,16),control1: pt(1.5,14),control2: pt(3.5,15.5)); p.addCurve(to: pt(7,18),control1: pt(6.9,16.4),control2: pt(7,17)); p.addLine(to: pt(7,22)); stroke(p.applying(CGAffineTransform(a: 0.9,b: 0,c: 0,d: 0.9,tx: 2,ty: -1)))
                }
            }
        } else { Image(systemName: fallback).resizable().scaledToFit() }
    }
}
