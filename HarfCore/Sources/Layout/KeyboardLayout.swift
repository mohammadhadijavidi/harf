import Foundation

/// A real macOS Arabic keyboard layout, paired key-for-key with the US layout.
public enum KeyboardLayout: String, CaseIterable, Sendable, Identifiable {
    /// `com.apple.keylayout.Arabic` (the default Arabic layout on a Mac).
    case apple
    /// `com.apple.keylayout.ArabicPC` (the Windows-style layout, "Arabic - PC").
    case pc

    public var id: String { rawValue }

    public var inputSourceID: String {
        switch self {
        case .apple: return "com.apple.keylayout.Arabic"
        case .pc: return "com.apple.keylayout.ArabicPC"
        }
    }

    public var displayName: String {
        switch self {
        case .apple: return "Arabic"
        case .pc: return "Arabic - PC"
        }
    }

    var entries: [KeyEntry] {
        switch self {
        case .apple: return Self.appleEntries
        case .pc: return Self.pcEntries
        }
    }
}

/// Which way to convert text that was typed with the wrong keyboard layout.
public enum ConversionDirection: String, CaseIterable, Sendable, Identifiable {
    /// Latin gibberish that was meant to be Arabic ("hgsghl" -> "السلام").
    case toArabic
    /// Arabic gibberish that was meant to be English ("اثممخ" -> "hello").
    case toLatin

    public var id: String { rawValue }
}

/// Result of a layout conversion, including what was detected.
public struct LayoutConversion: Sendable, Equatable {
    public let output: String
    public let direction: ConversionDirection
    public let layout: KeyboardLayout
    /// Share of output words recognised by the lexicon of the target language (0...1).
    public let recognisedRatio: Double
}

/// Converts text typed on the wrong keyboard layout, in both directions.
public struct KeyboardLayoutConverter: Sendable {
    public let data: LanguageData

    private struct Maps: Sendable {
        let toArabic: [Character: String]
        /// Arabic strings (one or two characters, e.g. the lam-alef key) to Latin.
        let toLatin: [String: Character]
    }

    private static let maps: [KeyboardLayout: Maps] = {
        var result: [KeyboardLayout: Maps] = [:]
        for layout in KeyboardLayout.allCases {
            var toArabic: [Character: String] = [:]
            var toLatin: [String: (Character, Int)] = [:]
            for e in layout.entries {
                guard let latin = e.latin.first, e.latin.count == 1 else { continue }
                if !e.isDigitKey, toArabic[latin] == nil { toArabic[latin] = e.arabic }
                // Prefer unshifted keys, then plain ASCII keys (` over § for the same letter).
                let priority = (e.shifted ? 2 : 0) + (latin.isASCII ? 0 : 1)
                if let existing = toLatin[e.arabic], existing.1 <= priority { continue }
                toLatin[e.arabic] = (latin, priority)
            }
            // Arabic-Indic digits typed on an Arabic layout mean Western digits.
            for (i, d) in "٠١٢٣٤٥٦٧٨٩".enumerated() where toLatin[String(d)] == nil {
                toLatin[String(d)] = (Character(String(i)), 9)
            }
            result[layout] = Maps(toArabic: toArabic, toLatin: toLatin.mapValues(\.0))
        }
        return result
    }()

    public init(data: LanguageData = .shared) { self.data = data }

    /// Latin text typed while the US layout was active, read as if the Arabic layout had been active.
    public func toArabic(_ text: String, layout: KeyboardLayout) -> String {
        guard let map = Self.maps[layout]?.toArabic else { return text }
        var out = ""
        for ch in text { out += map[ch] ?? String(ch) }
        return out
    }

    /// Arabic text typed while an Arabic layout was active, read as if the US layout had been active.
    public func toLatin(_ text: String, layout: KeyboardLayout) -> String {
        guard let map = Self.maps[layout]?.toLatin else { return text }
        let chars = Array(text)
        var out = ""
        var i = 0
        while i < chars.count {
            if i + 1 < chars.count, let latin = map[String(chars[i]) + String(chars[i + 1])] {
                out.append(latin)
                i += 2
                continue
            }
            if let latin = map[String(chars[i])] { out.append(latin) } else { out.append(chars[i]) }
            i += 1
        }
        return out
    }

    /// Picks the direction from the script of the text.
    public func detectDirection(_ text: String) -> ConversionDirection {
        let c = ArabicScript.counts(text)
        return c.arabic > c.latin ? .toLatin : .toArabic
    }

    /// Converts with automatic direction and layout detection (or with the ones given).
    public func convert(_ text: String, direction: ConversionDirection? = nil, layout: KeyboardLayout? = nil) -> LayoutConversion {
        let dir = direction ?? detectDirection(text)
        let layouts = layout.map { [$0] } ?? [.pc, .apple]
        var best: LayoutConversion?
        for l in layouts {
            let out = dir == .toArabic ? toArabic(text, layout: l) : toLatin(text, layout: l)
            let ratio = dir == .toArabic ? arabicScore(out) : englishScore(out)
            let candidate = LayoutConversion(output: out, direction: dir, layout: l, recognisedRatio: ratio)
            if best == nil || ratio > best!.recognisedRatio + 0.0001 { best = candidate }
        }
        return best!
    }

    // MARK: Scoring

    /// Share of Arabic words in the text that the lexicon knows (with and without the article).
    public func arabicScore(_ text: String) -> Double {
        let words = text.split { !ArabicScript.isArabicLetter($0.unicodeScalars.first ?? " ") && !$0.isNumber }
            .map(String.init).filter { ArabicScript.counts($0).arabic > 0 }
        guard !words.isEmpty else { return 0 }
        var known = 0.0
        for w in words {
            if data.isKnownArabic(w) { known += 1; continue }
            if w.hasPrefix("ال"), data.isKnownArabic(String(w.dropFirst(2))) { known += 1; continue }
            for p in ["و", "ب", "ل", "ف"] where w.hasPrefix(p) && w.count > 2 {
                if data.isKnownArabic(String(w.dropFirst())) { known += 0.8; break }
            }
        }
        return known / Double(words.count)
    }

    /// Share of Latin words that are common English words, softened by a vowel plausibility check.
    public func englishScore(_ text: String) -> Double {
        EnglishHeuristics.score(text)
    }
}
