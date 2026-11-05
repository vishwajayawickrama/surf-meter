import Foundation

public struct Platform: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String
    public let hex: UInt32
    public static let catalog: [Platform] = [
        .init(id: "youtube.com", name: "YouTube", symbol: "play.rectangle.fill", hex: 0xE24C4B),
        .init(id: "facebook.com", name: "Facebook", symbol: "person.2.fill", hex: 0x3478F6),
        .init(id: "instagram.com", name: "Instagram", symbol: "camera.fill", hex: 0xBA4FA1),
        .init(id: "x.com", name: "X / Twitter", symbol: "bubble.left.fill", hex: 0x526074),
        .init(id: "reddit.com", name: "Reddit", symbol: "bubble.left.and.bubble.right.fill", hex: 0xE46B39),
        .init(id: "tiktok.com", name: "TikTok", symbol: "music.note", hex: 0x278B92),
        .init(id: "linkedin.com", name: "LinkedIn", symbol: "person.crop.square.fill", hex: 0x3377AF)
    ]
    public static func named(_ id: String) -> Platform {
        catalog.first { $0.id == id } ?? .init(id: id, name: id, symbol: "globe", hex: 0x6686B8)
    }
}

/// Mozilla PSL, including private suffixes; rules are bundled for offline operation.
public struct DomainClassifier: Sendable {
    private let exact: Set<String>
    private let wildcard: Set<String>
    private let exceptions: Set<String>

    public init(rules: String) {
        var exact = Set<String>(), wildcard = Set<String>(), exceptions = Set<String>()
        for raw in rules.split(whereSeparator: \.isNewline) {
            let rule = raw.trimmingCharacters(in: .whitespaces)
            guard !rule.isEmpty, !rule.hasPrefix("//") else { continue }
            if rule.hasPrefix("!") { exceptions.insert(Self.ascii(String(rule.dropFirst()))) }
            else if rule.hasPrefix("*.") { wildcard.insert(Self.ascii(String(rule.dropFirst(2)))) }
            else { exact.insert(Self.ascii(rule)) }
        }
        self.exact = exact; self.wildcard = wildcard; self.exceptions = exceptions
    }

    public static func bundled() throws -> Self {
        guard let url = Bundle.module.url(forResource: "public_suffix_list", withExtension: "dat") else { throw ProtocolError.invalidState }
        return try Self(rules: String(contentsOf: url, encoding: .utf8))
    }

    private static func ascii(_ rule: String) -> String {
        URL(string: "https://\(rule)")?.host?.lowercased() ?? rule.lowercased()
    }

    public static func matches(_ hostname: String, domain: String) -> Bool {
        hostname == domain || hostname.hasSuffix("." + domain)
    }

    public func platform(for hostname: String) -> String {
        for platform in Platform.catalog where Self.matches(hostname, domain: platform.id) { return platform.id }
        if Self.matches(hostname, domain: "twitter.com") { return "x.com" }
        if Self.matches(hostname, domain: "youtu.be") { return "youtube.com" }
        return registrableDomain(hostname)
    }

    public func registrableDomain(_ hostname: String) -> String {
        let labels = hostname.split(separator: ".").map(String.init)
        if labels.count < 2 || labels.allSatisfy({ UInt8($0) != nil }) { return hostname }
        var suffixLength = 1
        for index in labels.indices {
            let suffix = labels[index...].joined(separator: ".")
            if exceptions.contains(suffix) {
                suffixLength = labels.count - index - 1
                break
            }
            if exact.contains(suffix) { suffixLength = max(suffixLength, labels.count - index) }
            if index > 0 && wildcard.contains(suffix) { suffixLength = max(suffixLength, labels.count - index + 1) }
        }
        return labels.suffix(min(labels.count, suffixLength + 1)).joined(separator: ".")
    }

    public static func exclusion(_ text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !clean.contains(":"), !clean.contains("/"), !clean.contains("?"), !clean.contains("#"),
              let host = URL(string: "https://\(clean)")?.host, !host.isEmpty,
              host.utf8.count <= 253,
              host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0.utf8.count <= 63 && $0.first != "-" && $0.last != "-" && $0.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 } }) else { return nil }
        return host
    }
}
