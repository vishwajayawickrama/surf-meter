import AppKit
import SwiftUI
import SurfMeterCore

/// Isolated verification and documentation renders; never opens the activity store.
@MainActor enum SiteIconAudit {
    static func verify() {
        func check(_ valid: @autoclosure () -> Bool, _ name: String) {
            guard valid() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
            print("PASS: \(name)")
        }
        let records = SiteIconCatalog.artwork
        check(records.count == 48, "all 48 bundled website identities load")
        let domains = records.flatMap { $0.metadata.domains }
        check(domains.count == 67 && Set(domains).count == domains.count, "67 unique domain aliases")
        check(records.allSatisfy { item in
            let bounds = item.path.boundingRect
            return !item.path.isEmpty && bounds.width > 0 && bounds.height > 0 && bounds.minX >= -0.25 && bounds.minY >= -0.25 && bounds.maxX <= 24.25 && bounds.maxY <= 24.25
        }, "every vector has nonempty, normalized bounds")
        for domain in ["youtube.com", "chatgpt.com", "google.com", "github.com", "linkedin.com", "reddit.com", "instagram.com", "spotify.com", "netflix.com", "slack.com"] {
            check(SiteIconCatalog.match(domain) != nil, "recognized artwork for \(domain)")
        }
        check(SiteIconCatalog.match("WWW.CHATGPT.COM.")?.metadata.title == "ChatGPT", "case and subdomain normalization")
        check(SiteIconCatalog.match("twitter.com")?.metadata.slug == "x", "Twitter alias uses X artwork")
        check(SiteIconCatalog.match("mail.google.com")?.metadata.title == "Gmail", "specific service beats parent-domain branding")
        check(SiteIconCatalog.match("youtube.com.evil.test") == nil && SiteIconCatalog.match("notyoutube.com") == nil, "unrelated domains cannot inherit brand artwork")
        check(SiteIconCatalog.fallbackInitial("www.example.test") == "E", "unknown site has a readable domain initial")
        let classifier = try! DomainClassifier.bundled()
        check(classifier.platform(for: "mail.google.com") == "google.com", "icon matching does not change stored grouping")
        check(Platform.named("chatgpt.com").displayName == "ChatGPT", "friendly title is presentation only")
    }
}

struct SiteIconGallery: View {
    let dark: Bool
    private var domains: [String] { SiteIconCatalog.artwork.map { $0.metadata.domains[0] } + ["example.test", "work.example.test", "reading.example.test"] }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Familiar sites. Familiar icons.").font(.system(size: 26, weight: .semibold))
                    Text("48 website identities · \(dark ? "Dark" : "Light") appearance").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Text("SURFMETER").font(.system(size: 11, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 17) {
                ForEach(domains, id: \.self) { domain in
                    VStack(spacing: 9) {
                        PlatformIcon(platform: .named(domain), size: 48)
                        Text(Platform.named(domain).displayName).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(height: 77).frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
        }.padding(32).foregroundStyle(SurfPalette(dark: dark).text)
            .background(SurfPalette(dark: dark).solid)
    }
}
