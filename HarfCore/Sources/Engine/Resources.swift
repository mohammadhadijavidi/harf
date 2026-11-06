import Foundation

private final class HarfCoreBundleToken {}

/// One curated Arabizi dictionary entry.
public struct ArabiziEntry: Sendable, Equatable {
    /// Arabic candidates, preferred first.
    public let candidates: [String]
    /// Dialect tags as written in the data files (C common, G Gulf, L Levantine, E Egyptian).
    public let dialects: [String]
}

/// Loads the bundled language data: the Arabizi dictionary and the Arabic lexicon.
///
/// Data files live in `HarfCore/Resources` (`arabizi-*.txt`, `lexicon-*.txt`) and are parsed once.
public final class LanguageData: Sendable {
    public static let shared = LanguageData()

    /// Folded Latin spelling (single spaces between words) to entry.
    public let arabizi: [String: ArabiziEntry]
    /// Longest multi-word spelling in the dictionary, in words.
    public let maxPhraseWords: Int
    /// Arabic lexicon: lookup key to (spelling as written, rank). Lower rank = more common.
    public let lexicon: [String: (word: String, rank: Int)]
    /// Lexicon words in rank order.
    public let lexiconWords: [String]

    public convenience init() {
        let bundle = Bundle(for: HarfCoreBundleToken.self)
        func read(_ prefix: String) -> [String] {
            let urls = (bundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? [])
                .filter { $0.lastPathComponent.hasPrefix(prefix) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            return urls.compactMap { try? String(contentsOf: $0, encoding: .utf8) }
        }
        self.init(arabiziSources: read("arabizi-"), lexiconSources: read("lexicon-"))
    }

    /// Builds the data from raw file contents (used by tests and by `init()`).
    public init(arabiziSources: [String], lexiconSources: [String]) {
        var dict: [String: ArabiziEntry] = [:]
        var maxWords = 1
        for source in arabiziSources {
            for rawLine in source.split(whereSeparator: \.isNewline) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                let parts = line.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 2 else { continue }
                let spellings = parts[0].split(separator: ",").map { LanguageData.fold(String($0)) }.filter { !$0.isEmpty }
                var candidates: [String] = []
                for c in parts[1].split(separator: ",") {
                    let t = c.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty && !candidates.contains(t) { candidates.append(t) }
                }
                guard !candidates.isEmpty else { continue }
                let dialects = parts.count > 2 ? parts[2].split(separator: " ").map(String.init) : []
                for s in spellings {
                    maxWords = max(maxWords, s.split(separator: " ").count)
                    if let existing = dict[s] {
                        var merged = existing.candidates
                        for c in candidates where !merged.contains(c) { merged.append(c) }
                        dict[s] = ArabiziEntry(candidates: merged, dialects: existing.dialects)
                    } else {
                        dict[s] = ArabiziEntry(candidates: candidates, dialects: dialects)
                    }
                }
            }
        }
        var lex: [String: (word: String, rank: Int)] = [:]
        var words: [String] = []
        for source in lexiconSources {
            for rawLine in source.split(whereSeparator: \.isNewline) {
                let w = rawLine.trimmingCharacters(in: .whitespaces)
                if w.isEmpty || w.hasPrefix("#") { continue }
                let key = ArabicScript.lookupKey(w)
                if lex[key] == nil { lex[key] = (w, words.count) }
                words.append(w)
            }
        }
        self.arabizi = dict
        self.maxPhraseWords = min(maxWords, 4)
        self.lexicon = lex
        self.lexiconWords = words
    }

    /// Lowercases, removes Latin diacritics and collapses whitespace.
    public static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Lexicon entry for an Arabic word, matched loosely (alef forms, ya, ta marbuta, tashkeel).
    public func lexiconEntry(_ arabic: String) -> (word: String, rank: Int)? {
        lexicon[ArabicScript.lookupKey(arabic)]
    }

    public func isKnownArabic(_ arabic: String) -> Bool { lexiconEntry(arabic) != nil }
}
