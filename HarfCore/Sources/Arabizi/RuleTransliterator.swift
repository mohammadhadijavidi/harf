import Foundation

/// Deterministic letter-by-letter Arabizi rules with candidate generation.
///
/// A word is split into units (consonants, digit letters, digraphs, vowel clusters). Every unit has
/// one or more Arabic options with a cost (0 = the default reading). All combinations are generated
/// with a small beam, then ranked: spellings found in the Arabic lexicon win, otherwise the
/// cheapest reading wins.
struct RuleTransliterator: Sendable {
    let data: LanguageData

    struct Candidate: Equatable {
        var text: String
        var cost: Int
        var inLexicon: Bool
    }

    private enum Unit: Equatable {
        case consonant(String, upper: Bool)
        case vowel(String)
        case hamza          // "2" or a lone apostrophe
        case taMarbuta      // final "ah"/"eh"
    }

    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
    private static let digraphs: Set<String> = ["sh", "ch", "kh", "gh", "th", "dh"]

    private static let consonantOptions: [String: [String]] = [
        "b": ["ب"], "p": ["ب"], "t": ["ت", "ط"], "th": ["ث", "ت"], "j": ["ج"], "g": ["ج", "ق", "غ"],
        "7": ["ح"], "h": ["ه", "ح"], "kh": ["خ"], "5": ["خ"], "7'": ["خ"], "d": ["د", "ض"],
        "dh": ["ذ", "ض", "ظ"], "r": ["ر"], "z": ["ز", "ظ"], "s": ["س", "ص"], "sh": ["ش"], "ch": ["ش"],
        "9": ["ص"], "9'": ["ض"], "6": ["ط"], "6'": ["ظ"], "3": ["ع"], "3'": ["غ"], "gh": ["غ"],
        "f": ["ف"], "v": ["ف"], "q": ["ق"], "8": ["ق", "غ"], "k": ["ك"], "c": ["ك", "س"], "l": ["ل"],
        "m": ["م"], "n": ["ن"], "w": ["و"], "y": ["ي"], "x": ["كس"], "4": ["ش"],
    ]
    /// Uppercase letters inside a word are a common way to mark emphatic consonants.
    private static let emphatic: [String: String] = ["s": "ص", "t": "ط", "d": "ض", "h": "ح", "z": "ظ", "g": "غ"]

    // MARK: Parsing

    private func parse(_ folded: [Character], upperFlags: [Bool]) -> [Unit] {
        var units: [Unit] = []
        var i = 0
        let n = folded.count
        func upper(_ k: Int) -> Bool { k > 0 && k < upperFlags.count && upperFlags[k] }
        while i < n {
            let c = folded[i]
            if c.isNumber {
                if i + 1 < n, folded[i + 1] == "'", "3967".contains(c) {
                    appendConsonant(String(c) + "'", upper: false, to: &units)
                    i += 2
                } else if c == "2" {
                    units.append(.hamza)
                    i += 1
                } else {
                    appendConsonant(String(c), upper: false, to: &units)
                    i += 1
                }
            } else if c == "'" {
                if case .hamza? = units.last {} else { units.append(.hamza) }
                i += 1
            } else if Self.vowels.contains(c) {
                var run = ""
                while i < n, Self.vowels.contains(folded[i]) { run.append(folded[i]); i += 1 }
                units.append(.vowel(run))
            } else {
                if i + 1 < n, Self.digraphs.contains(String([c, folded[i + 1]])) {
                    appendConsonant(String([c, folded[i + 1]]), upper: false, to: &units)
                    i += 2
                } else {
                    appendConsonant(String(c), upper: upper(i), to: &units)
                    i += 1
                }
            }
        }
        // Final "ah"/"eh" after at least two consonants reads as ta marbuta.
        if units.count >= 3, case .consonant("h", upper: false) = units[units.count - 1],
           case .vowel(let v) = units[units.count - 2], v == "a" || v == "e" {
            let consonants = units.dropLast(2).filter { if case .vowel = $0 { return false } else { return true } }.count
            if consonants >= 2 { units.removeLast(2); units.append(.taMarbuta) }
        }
        return units
    }

    private func appendConsonant(_ key: String, upper: Bool, to units: inout [Unit]) {
        // A doubled consonant (shadda) is written once.
        if case .consonant(let prev, let prevUpper)? = units.last, prev == key {
            if upper && !prevUpper { units[units.count - 1] = .consonant(key, upper: true) }
            return
        }
        units.append(.consonant(key, upper: upper))
    }

    // MARK: Options

    private func options(for units: [Unit]) -> [[(String, Int)]] {
        let consonantCount = units.filter { if case .vowel = $0 { return false } else { return true } }.count
        var result: [[(String, Int)]] = []
        var explicitHamzaStart = false
        for (k, unit) in units.enumerated() {
            let isFirst = k == 0 || (k == 1 && explicitHamzaStart)
            let isLast = k == units.count - 1
            switch unit {
            case .consonant(let key, let upper):
                var opts = Self.consonantOptions[key] ?? [key]
                if upper, let e = Self.emphatic[key] {
                    opts.removeAll { $0 == e }
                    opts.insert(e, at: 0)
                }
                result.append(opts.enumerated().map { ($0.element, $0.offset) })
            case .taMarbuta:
                result.append([("ة", 0), ("ه", 1)])
            case .hamza:
                if k == 0 {
                    if units.count > 1, case .vowel = units[1] {
                        explicitHamzaStart = true
                        result.append([("", 0)]) // the following vowel carries the hamza
                    } else {
                        result.append([("أ", 0), ("ء", 1)])
                    }
                } else if isLast {
                    result.append([("ء", 0)])
                } else {
                    let prev = vowelAt(units, k - 1)
                    let next = vowelAt(units, k + 1)
                    let around = (prev ?? "") + (next ?? "")
                    if around.contains("i") || around.contains("e") {
                        result.append([("ئ", 0), ("ء", 1), ("أ", 2)])
                    } else if around.contains("o") || around.contains("u") {
                        result.append([("ؤ", 0), ("ء", 1), ("أ", 2)])
                    } else if next != nil {
                        result.append([("أ", 0), ("ء", 1)])
                    } else {
                        result.append([("ء", 0), ("أ", 1)])
                    }
                }
            case .vowel(let v):
                let followedByHamza: Bool = { if k + 1 < units.count, case .hamza = units[k + 1] { return true } else { return false } }()
                if isFirst && isLast {
                    result.append(loneVowel(v))
                } else if isFirst {
                    result.append(initialVowel(v, explicitHamza: explicitHamzaStart))
                } else if isLast {
                    result.append(finalVowel(v, consonantCount: consonantCount))
                } else {
                    var opts = medialVowel(v, finalSyllable: isFinalSyllable(units, k), consonantCount: consonantCount)
                    if followedByHamza && v.count == 1 {
                        // The vowel only chooses the hamza seat here.
                        opts = [("", 0)] + opts.filter { !$0.0.isEmpty }.map { ($0.0, $0.1 + 1) }
                    }
                    result.append(opts)
                }
            }
        }
        return result
    }

    private func vowelAt(_ units: [Unit], _ k: Int) -> String? {
        guard k >= 0, k < units.count, case .vowel(let v) = units[k] else { return nil }
        return v
    }

    /// A vowel followed by exactly one consonant and then the end of the word (or a word-final vowel),
    /// as in "kit-AB", "kb-I-ra".
    private func isFinalSyllable(_ units: [Unit], _ k: Int) -> Bool {
        guard k + 1 < units.count else { return false }
        if case .vowel = units[k + 1] { return false }
        if k + 2 == units.count { return true }
        if k + 3 == units.count, case .vowel = units[k + 2] { return true }
        return false
    }

    private func longVowel(_ c: Character) -> String {
        switch c {
        case "a": return "ا"
        case "o", "u": return "و"
        default: return "ي"
        }
    }

    private func genericLong(_ v: String) -> String {
        var out = ""
        var last = ""
        for c in v {
            let l = longVowel(c)
            if l != last { out += l; last = l }
        }
        return out
    }

    private func loneVowel(_ v: String) -> [(String, Int)] {
        switch v {
        case "o", "u", "ou", "oo", "w": return [("و", 0), ("أو", 1)]
        case "a": return [("أ", 0), ("ا", 1)]
        case "e", "i": return [("إ", 0), ("ي", 1)]
        default: return [("ا" + genericLong(v), 0)]
        }
    }

    private func initialVowel(_ v: String, explicitHamza: Bool) -> [(String, Int)] {
        switch v {
        case "a": return [("أ", 0), ("ا", 1)]
        case "aa": return [("آ", 0), ("ا", 1)]
        case "e", "i": return explicitHamza ? [("إ", 0), ("أ", 1), ("ا", 2)] : [("ا", 0), ("إ", 1)]
        case "o", "u": return [("أ", 0), ("ا", 1), ("أو", 2)]
        case "ee", "ii", "ei", "ai", "ie": return [("اي", 0), ("إي", 1)]
        case "oo", "ou", "uu": return [("أو", 0), ("او", 1)]
        default:
            let first = v.first.map { $0 == "e" || $0 == "i" ? "إ" : "أ" } ?? "ا"
            return [(first + genericLong(String(v.dropFirst())), 0)]
        }
    }

    private func finalVowel(_ v: String, consonantCount: Int) -> [(String, Int)] {
        let long = consonantCount >= 3
        switch v {
        case "a": return long ? [("ة", 0), ("ا", 1), ("ى", 2)] : [("ا", 0), ("ة", 1), ("ى", 2)]
        case "aa": return [("ا", 0), ("اء", 1)]
        case "e": return long ? [("ة", 0), ("ي", 1), ("ه", 2)] : [("ي", 0), ("ة", 1), ("ه", 2)]
        case "i", "ee", "ii", "ie", "ei", "ai", "ey": return [("ي", 0)]
        case "o", "u": return [("و", 0), ("ه", 1)]
        case "oo", "ou", "uu": return [("و", 0)]
        default:
            // e.g. "ia" -> "ية" / "يا"
            let head = genericLong(String(v.dropLast()))
            if let last = v.last, last == "a" || last == "e" {
                return [(head + "ة", 0), (head + "ا", 1)]
            }
            return [(genericLong(v), 0)]
        }
    }

    private func medialVowel(_ v: String, finalSyllable: Bool, consonantCount: Int) -> [(String, Int)] {
        switch v {
        case "a": return (finalSyllable && consonantCount <= 3) ? [("ا", 0), ("", 1)] : [("", 0), ("ا", 1)]
        case "aa": return [("ا", 0)]
        case "e": return [("", 0), ("ي", 1)]
        case "i": return finalSyllable ? [("ي", 0), ("", 1)] : [("", 0), ("ي", 1)]
        case "o", "u": return [("و", 0), ("", 1)]
        case "ee", "ii", "ei", "ie": return [("ي", 0)]
        case "ai": return [("ي", 0), ("اي", 1)]
        case "oo", "ou", "uu", "ao", "au": return [("و", 0)]
        default: return [(genericLong(v), 0)]
        }
    }

    // MARK: Candidates

    /// Ranked Arabic candidates for one Latin word (best first, at most `limit`).
    func candidates(for word: String, limit: Int = 6) -> [Candidate] {
        let folded = Array(LanguageData.fold(word))
        guard !folded.isEmpty else { return [] }
        let originalChars = Array(word)
        let upperFlags: [Bool] = originalChars.count == folded.count
            ? originalChars.map { $0.isUppercase }
            : Array(repeating: false, count: folded.count)
        let units = parse(folded, upperFlags: upperFlags)
        let opts = options(for: units)

        var beam: [(String, Int)] = [("", 0)]
        for unitOptions in opts {
            var next: [(String, Int)] = []
            next.reserveCapacity(beam.count * unitOptions.count)
            for (text, cost) in beam {
                for (o, c) in unitOptions { next.append((text + o, cost + c)) }
            }
            next.sort { $0.1 < $1.1 }
            beam = Array(next.prefix(384))
        }

        var best: [String: Candidate] = [:]
        for (text, cost) in beam where !text.isEmpty {
            let entry = data.lexiconEntry(text)
            let shown = entry?.word ?? text
            let cand = Candidate(text: shown, cost: cost, inLexicon: entry != nil)
            if let existing = best[shown], score(existing) >= score(cand) { continue }
            best[shown] = cand
        }
        return best.values.sorted {
            let a = score($0), b = score($1)
            return a != b ? a > b : $0.text < $1.text
        }.prefix(limit).map { $0 }
    }

    private func score(_ c: Candidate) -> Double {
        if c.inLexicon {
            let rank = Double(data.lexiconEntry(c.text)?.rank ?? 2000)
            return 1000 - Double(c.cost) * 30 - min(rank, 2000) / 50
        }
        return -Double(c.cost) * 10
    }
}
