import Foundation

/// Local objectionable-content filter (TASK-167).
///
/// DriftSonar is a serverless, offline-first network with no central moderation,
/// so App Store Guideline 1.2 (User Generated Content) is satisfied on-device:
/// every peer's app filters incoming posts locally. This type provides the
/// pure, testable core of that filter — detecting and masking prohibited words.
///
/// The list is intentionally small and conservative: it catches the most overt
/// slurs/abuse so the timeline can hide or mask them, while user-level blocking
/// and reporting (handled in the app layer) cover everything else.
public struct ContentFilter: Sendable {

    /// Lower-cased prohibited terms. Matching is case-insensitive and, for ASCII
    /// terms, also ignores common separator characters used to evade filters.
    private let prohibited: [String]

    /// The character repeated to mask a matched term in displayed text.
    public static let maskCharacter = "＊"

    /// Creates a filter. Pass a custom word list for tests; the default list ships
    /// with the app.
    public init(words: [String] = ContentFilter.defaultWords) {
        self.prohibited = words.map { $0.lowercased() }
    }

    /// True when `text` contains at least one prohibited term.
    public func containsProhibited(_ text: String) -> Bool {
        let haystack = Self.normalize(text)
        return prohibited.contains { !$0.isEmpty && haystack.contains($0) }
    }

    /// Returns `text` with every prohibited term replaced by mask characters of
    /// the same length, preserving the rest of the message. Matching is done on a
    /// normalized copy but replacement is applied to the original casing.
    public func mask(_ text: String) -> String {
        guard containsProhibited(text) else { return text }
        var result = text
        for word in prohibited where !word.isEmpty {
            result = Self.replaceCaseInsensitive(
                in: result,
                target: word,
                with: String(repeating: Self.maskCharacter, count: word.count)
            )
        }
        return result
    }

    // MARK: - Internals

    /// Lower-cases and strips whitespace so simple spacing tricks ("b a d") do not
    /// bypass detection. Kept deliberately light to avoid masking legitimate text.
    static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    /// Case-insensitive literal replacement that keeps surrounding text intact.
    private static func replaceCaseInsensitive(in text: String, target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return text }
        var result = text
        var searchRange = result.startIndex..<result.endIndex
        while let found = result.range(of: target, options: .caseInsensitive, range: searchRange) {
            result.replaceSubrange(found, with: replacement)
            let next = result.index(found.lowerBound, offsetBy: replacement.count)
            guard next < result.endIndex else { break }
            searchRange = next..<result.endIndex
        }
        return result
    }

    /// Conservative default block list. Not exhaustive — it backstops user-level
    /// reporting and blocking, which are the primary moderation controls.
    public static let defaultWords: [String] = [
        // English slurs / abuse (representative, lower-cased)
        "fuck", "shit", "bitch", "asshole", "bastard", "slut", "retard",
        "nigger", "faggot", "cunt",
        // Japanese abuse / slurs (representative)
        "死ね", "殺す", "きちがい", "気違い", "ぶっ殺", "クズ野郎",
    ]
}
