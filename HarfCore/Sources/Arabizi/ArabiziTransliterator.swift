import Foundation

/// Converts Arabizi (Franco-Arabic, Arabic chat alphabet) into Arabic script.
///
/// Order of precedence for every word:
/// 1. multi-word phrases and words from the curated dictionary,
/// 2. the article (el/al/il, attached or separate, including sun-letter forms like "ash-shams"),
/// 3. attached particles (w-, b-, f-, l-, k-) and pronoun suffixes around a dictionary word,
/// 4. the deterministic rule engine, ranked by the Arabic lexicon.
public struct ArabiziTransliterator: Sendable {
    public let data: LanguageData
    private let rules: RuleTransliterator

    public init(data: LanguageData = .shared) {
        self.data = data
        self.rules = RuleTransliterator(data: data)
    }

    // MARK: Tokens

    enum Token: Equatable {
        case word(String)
        case space(String)
        case verbatim(String)    // URLs, emails, mentions, hashtags
        case other(String)       // punctuation and anything else
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var chunk = ""
        var spaces = ""
        func flushChunk() {
            guard !chunk.isEmpty else { return }
            if isVerbatim(chunk) { tokens.append(.verbatim(chunk)) } else { tokens += splitWords(chunk) }
            chunk = ""
        }
        for ch in text {
            if ch.isWhitespace {
                flushChunk()
                spaces.append(ch)
            } else {
                if !spaces.isEmpty { tokens.append(.space(spaces)); spaces = "" }
                chunk.append(ch)
            }
        }
        flushChunk()
        if !spaces.isEmpty { tokens.append(.space(spaces)) }
        return tokens
    }

    private static func isVerbatim(_ chunk: String) -> Bool {
        let lower = chunk.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") { return true }
        if chunk.hasPrefix("@") || chunk.hasPrefix("#") { return chunk.count > 1 }
        if chunk.contains("@"), chunk.contains(".") { return true }
        return false
    }

    private static func isWordChar(_ c: Character) -> Bool {
        if c.isASCII { return c.isLetter || c.isNumber }
        return c.unicodeScalars.allSatisfy { ArabicScript.isLatinLetter($0) || (0x0300...0x036F).contains($0.value) }
    }

    private static func splitWords(_ chunk: String) -> [Token] {
        var out: [Token] = []
        let chars = Array(chunk)
        var i = 0
        var word = ""
        func flush() { if !word.isEmpty { out.append(.word(word)); word = "" } }
        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if isWordChar(c) {
                word.append(c)
            } else if (c == "'" || c == "\u{2019}"), !word.isEmpty {
                // 3' 9' 6' 7' are letters; an apostrophe inside a word is a hamza.
                if let last = word.last, "3967".contains(last) {
                    word.append("'")
                } else if let n = next, isWordChar(n) {
                    word.append("'")
                } else {
                    flush(); out.append(.other(String(c)))
                }
            } else if c == "-", !word.isEmpty, let n = next, isWordChar(n) {
                word.append("-")
            } else {
                flush()
                out.append(.other(String(c)))
            }
            i += 1
        }
        flush()
        return out
    }

    // MARK: Public API

    public func transliterate(_ text: String) -> ArabiziResult {
        let tokens = Self.tokenize(text)
        var segments: [ArabiziSegment] = []
        var i = 0
        func add(_ source: String, _ origin: ArabiziSegment.Source, _ candidates: [String]) {
            segments.append(ArabiziSegment(id: segments.count, source: source, origin: origin, candidates: candidates))
        }
        while i < tokens.count {
            switch tokens[i] {
            case .space(let s):
                add(s, .passthrough, [s])
                i += 1
            case .verbatim(let s):
                add(s, .passthrough, [s])
                i += 1
            case .other(let s):
                add(s, .passthrough, [Self.punctuation[s] ?? s])
                i += 1
            case .word(let w):
                // 1. longest dictionary phrase starting here
                if let phrase = longestPhrase(tokens, from: i) {
                    add(phrase.1, .dictionary, phrase.2.candidates)
                    i += phrase.0
                    continue
                }
                // 2. a separate article: "el beit", "al kitab"
                if Self.articles.contains(LanguageData.fold(w)), i + 2 < tokens.count,
                   case .space(let sp) = tokens[i + 1], !sp.contains(where: \.isNewline),
                   case .word(let nextWord) = tokens[i + 2], !Self.articles.contains(LanguageData.fold(nextWord)) {
                    let inner = convertWord(nextWord)
                    if inner.origin != .passthrough {
                        let cands = unique(inner.candidates.map { Self.withArticle($0) })
                        add(w + sp + nextWord, inner.origin, cands)
                        i += 3
                        continue
                    }
                }
                let converted = convertWord(w)
                add(w, converted.origin, converted.candidates)
                i += 1
            }
        }
        return ArabiziResult(segments: segments)
    }

    /// Converts a single word without phrase context.
    public func convertWord(_ word: String) -> (origin: ArabiziSegment.Source, candidates: [String]) {
        let folded = LanguageData.fold(word)
        if folded.allSatisfy(\.isNumber) { return (.passthrough, [word]) }
        if word.count >= 2, word.count <= 5, word.allSatisfy({ $0.isUppercase && $0.isLetter }) {
            return (.passthrough, [word])   // acronyms such as PDF, OK
        }
        if let entry = data.arabizi[folded] { return (.dictionary, entry.candidates) }

        // Hyphenated: article forms ("al-kitab", "ash-shams") or compounds.
        if folded.contains("-") {
            let parts = folded.split(separator: "-", maxSplits: 1).map(String.init)
            if parts.count == 2, isArticlePrefix(parts[0], before: parts[1]) {
                let inner = convertWord(parts[1])
                return (inner.origin == .passthrough ? .rules : inner.origin, unique(inner.candidates.map { Self.withArticle($0) }))
            }
            let all = folded.split(separator: "-").map { convertWord(String($0)) }
            let joined = all.map { $0.candidates[0] }.joined(separator: " ")
            let origin: ArabiziSegment.Source = all.allSatisfy { $0.origin == .dictionary } ? .dictionary : .rules
            return (origin, [joined])
        }

        // Attached article: "elbeit", "ilsayyara".
        for prefix in ["el", "al", "il"] where folded.hasPrefix(prefix) && folded.count >= prefix.count + 3 {
            let rest = String(folded.dropFirst(prefix.count))
            if let known = knownStem(rest) {
                return (known.origin, unique(known.candidates.map { Self.withArticle($0) }))
            }
        }

        // A whole-word rule reading confirmed by the lexicon beats splitting off particles.
        let ranked = rules.candidates(for: word)
        if let top = ranked.first, top.inLexicon { return (.lexicon, ranked.map(\.text)) }

        // Particles: "wana" (وأنا), "lal madrase".
        for (prefix, arabic) in Self.particles where folded.hasPrefix(prefix) && folded.count >= prefix.count + 3 {
            let rest = String(folded.dropFirst(prefix.count))
            if let known = knownStem(rest) {
                return (known.origin, unique(known.candidates.map { arabic + $0 }))
            }
        }
        for (prefix, arabic) in Self.particlesWithArticle where folded.hasPrefix(prefix) && folded.count >= prefix.count + 3 {
            let rest = String(folded.dropFirst(prefix.count))
            if let known = knownStem(rest) {
                return (known.origin, unique(known.candidates.map { arabic + Self.stripArticle($0) }))
            }
        }

        // Pronoun suffixes on a dictionary word: "beitna" (بيتنا), "sayyartak".
        for (suffix, arabic) in Self.suffixes where folded.hasSuffix(suffix) && folded.count >= suffix.count + 2 {
            let stem = String(folded.dropLast(suffix.count))
            if let entry = data.arabizi[stem] {
                return (.dictionary, unique(entry.candidates.map { Self.attachSuffix(arabic, to: $0) }))
            }
            // "sayyaratna", "madrastak": the ta marbuta of the stem is pronounced t before a suffix.
            if stem.hasSuffix("t"), stem.count >= 4 {
                let bare = String(stem.dropLast())
                var tries = [bare + "a", bare + "e", bare + "eh", bare + "ah"]
                if bare.hasSuffix("a") || bare.hasSuffix("e") { tries.insert(bare, at: 0) }
                for t in tries {
                    if let entry = data.arabizi[t] {
                        let withTa = entry.candidates.filter { $0.hasSuffix("ة") }
                        if !withTa.isEmpty {
                            return (.dictionary, unique(withTa.map { Self.attachSuffix(arabic, to: $0) }))
                        }
                    }
                }
            }
        }

        guard let top = ranked.first else { return (.passthrough, [word]) }
        return (top.inLexicon ? .lexicon : .rules, ranked.map(\.text))
    }

    // MARK: Helpers

    private func longestPhrase(_ tokens: [Token], from start: Int) -> (Int, String, ArabiziEntry)? {
        guard data.maxPhraseWords >= 1 else { return nil }
        var words: [String] = []
        var source = ""
        var consumed = 0
        var best: (Int, String, ArabiziEntry)?
        var j = start
        while j < tokens.count, words.count < data.maxPhraseWords {
            guard case .word(let w) = tokens[j] else { break }
            words.append(w)
            source += w
            consumed = j - start + 1
            if words.count >= 2, let entry = data.arabizi[LanguageData.fold(words.joined(separator: " "))] {
                best = (consumed, source, entry)
            }
            guard j + 2 < tokens.count, case .space(let sp) = tokens[j + 1], !sp.contains(where: \.isNewline) else { break }
            source += sp
            j += 2
        }
        return best
    }

    /// A stem we are confident about: in the dictionary, or a rule reading found in the lexicon.
    private func knownStem(_ rest: String) -> (origin: ArabiziSegment.Source, candidates: [String])? {
        if let entry = data.arabizi[rest] { return (.dictionary, entry.candidates) }
        let ranked = rules.candidates(for: rest)
        if let top = ranked.first, top.inLexicon {
            return (.lexicon, ranked.filter(\.inLexicon).map(\.text))
        }
        return nil
    }

    private func isArticlePrefix(_ p: String, before rest: String) -> Bool {
        if Self.articles.contains(p) { return true }
        // Sun-letter assimilation: as-salam, ash-shams, ad-dar, an-nas, ar-rajul, at-tali.
        guard let first = p.first, "aei".contains(first) else { return false }
        let consonant = String(p.dropFirst())
        return !consonant.isEmpty && consonant.count <= 2 && rest.hasPrefix(consonant)
            && Self.sunLetters.contains(consonant)
    }

    static func withArticle(_ arabic: String) -> String {
        arabic.hasPrefix("ال") ? arabic : "ال" + arabic
    }

    static func stripArticle(_ arabic: String) -> String {
        arabic.hasPrefix("ال") ? String(arabic.dropFirst(2)) : arabic
    }

    static func attachSuffix(_ suffix: String, to stem: String) -> String {
        var s = stem
        if s.hasSuffix("ة") { s = String(s.dropLast()) + "ت" }
        if s.hasSuffix("ى") { s = String(s.dropLast()) + "ا" }
        return s + suffix
    }

    private func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    static let articles: Set<String> = ["el", "al", "il", "l"]
    static let sunLetters: Set<String> = ["t", "th", "d", "dh", "r", "z", "s", "sh", "9", "6", "n", "l", "ss", "tt", "dd"]
    static let particles: [(String, String)] = [("wa", "و"), ("w", "و"), ("u", "و"), ("bi", "ب"), ("b", "ب"),
                                                ("fa", "ف"), ("f", "ف"), ("li", "ل"), ("la", "ل"), ("ka", "ك")]
    static let particlesWithArticle: [(String, String)] = [("wel", "وال"), ("wil", "وال"), ("wal", "وال"),
                                                           ("bel", "بال"), ("bil", "بال"), ("bl", "بال"),
                                                           ("fel", "فال"), ("fil", "فال"),
                                                           ("lal", "لل"), ("lil", "لل"), ("ll", "لل")]
    static let suffixes: [(String, String)] = [("kom", "كم"), ("kum", "كم"), ("hom", "هم"), ("hum", "هم"),
                                               ("kon", "كن"), ("hon", "هن"), ("na", "نا"), ("ha", "ها"),
                                               ("ni", "ني"), ("ak", "ك"), ("ek", "ك"), ("ik", "ك"),
                                               ("o", "ه"), ("ou", "ه"), ("i", "ي"), ("y", "ي")]
    static let punctuation: [String: String] = ["?": "؟", ",": "،", ";": "؛"]
}
