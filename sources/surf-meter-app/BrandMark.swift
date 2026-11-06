import SwiftUI
import SurfMeterCore

/// Bundled upstream artwork, decoded and converted to paths once per process.
/// Website history never leaves the Mac to resolve an icon.
enum SiteIconCatalog {
    struct Metadata: Decodable {
        let slug: String
        let title: String
        let domains: [String]
        let hex: String
        let monochrome: Bool
        let commands: [[Double]]
    }
    struct Artwork {
        let metadata: Metadata
        let path: Path
    }
    static let artwork: [Artwork] = {
        guard let url = Bundle.module.url(forResource: "brands", withExtension: "json", subdirectory: "site-icons"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Metadata].self, from: data) else { return [] }
        return records.map { metadata in
            let path = Path { path in
                for values in metadata.commands {
                    switch values.first {
                    case 0 where values.count == 3: path.move(to: CGPoint(x: values[1], y: values[2]))
                    case 1 where values.count == 3: path.addLine(to: CGPoint(x: values[1], y: values[2]))
                    case 2 where values.count == 7:
                        path.addCurve(to: CGPoint(x: values[5], y: values[6]), control1: CGPoint(x: values[1], y: values[2]), control2: CGPoint(x: values[3], y: values[4]))
                    case 3 where values.count == 5:
                        path.addQuadCurve(to: CGPoint(x: values[3], y: values[4]), control: CGPoint(x: values[1], y: values[2]))
                    case 4: path.closeSubpath()
                    default: break
                    }
                }
            }
            return Artwork(metadata: metadata, path: path)
        }
    }()
    private static let domains: [(String, Artwork)] = artwork.flatMap { item in item.metadata.domains.map { ($0, item) } }
        .sorted { $0.0.count > $1.0.count }

    static func match(_ hostname: String) -> Artwork? {
        let hostname = hostname.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domains.first { DomainClassifier.matches(hostname, domain: $0.0) }?.1
    }
    static func fallbackInitial(_ hostname: String) -> String {
        let value = hostname.lowercased().hasPrefix("www.") ? String(hostname.dropFirst(4)) : hostname
        return value.first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "?"
    }
    static func fallbackColor(_ hostname: String) -> UInt32 {
        let colors: [UInt32] = [0x376DA3, 0x7B539D, 0x297A73, 0xA85B38, 0x5165A8, 0x9C4874]
        let hash = hostname.lowercased().utf8.reduce(UInt32(5381)) { ($0 &* 33) &+ UInt32($1) }
        return colors[Int(hash % UInt32(colors.count))]
    }
}

extension Platform {
    var displayName: String { SiteIconCatalog.match(id)?.metadata.title ?? name }
}

struct BrandMark: View {
    let id: String
    let fallback: String
    var body: some View {
        Canvas { context, size in
            if let artwork = SiteIconCatalog.match(id) {
                context.scaleBy(x: size.width / 24, y: size.height / 24)
                context.fill(artwork.path, with: .foreground)
            } else {
                let letter = Text(SiteIconCatalog.fallbackInitial(id)).font(.system(size: size.height * 0.82, weight: .semibold, design: .rounded))
                context.draw(letter.foregroundColor(.primary), at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        }
    }
}
