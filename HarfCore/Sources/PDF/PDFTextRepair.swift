import Foundation

/// Repairs Arabic text copied out of PDFs and old documents.
///
/// Typical damage: glyphs stored as Arabic Presentation Forms (U+FB50–U+FDFF, U+FE70–U+FEFC),
/// lines stored in visual order (letters and words reversed), lam-alef ligatures, tatweel used for
/// justification, and invisible characters.
public struct PDFTextRepair: Sendable {
    public enum ReversalMode: String, Sendable, CaseIterable, Identifiable {
        case automatic, always, never
        public var id: String { rawValue }
    }

    public struct Options: Sendable, Equatable {
        public var reversal: ReversalMode = .automatic
        public var removeTatweel = true
        public var removeInvisibles = true
        public var collapseSpaces = true
        public init() {}
    }

    public struct Report: Sendable, Equatable {
        public var presentationFormsMapped = 0
        public var ligaturesSplit = 0
        public var tatweelRemoved = 0
        public var invisiblesRemoved = 0
        public var reversedLines = 0
        public var reversalEvidence = ReversalEvidence()

        public var changedAnything: Bool {
            presentationFormsMapped + ligaturesSplit + tatweelRemoved + invisiblesRemoved + reversedLines > 0
        }
    }

    /// Scores for "this text is in logical order" vs "this text is in visual (reversed) order".
    public struct ReversalEvidence: Sendable, Equatable {
        public var logical = 0.0
        public var reversed = 0.0
        public var isReversed: Bool { reversed > logical && reversed >= 1 }
    }

    public let data: LanguageData

    public init(data: LanguageData = .shared) { self.data = data }

    public func repair(_ text: String, options: Options = Options()) -> (text: String, report: Report) {
        var report = Report()
        let evidence = reversalEvidence(text)
        report.reversalEvidence = evidence
        let reverse: Bool
        switch options.reversal {
        case .automatic: reverse = evidence.isReversed
        case .always: reverse = true
        case .never: reverse = false
        }

        var lines = text.components(separatedBy: "\n")
        if reverse {
            lines = lines.map { line in
                guard ArabicScript.counts(line).arabic > 0 else { return line }
                report.reversedLines += 1
                return Self.visualToLogical(line)
            }
        }
        var out = lines.joined(separator: "\n")

        // Presentation forms back to base letters, one scalar at a time (NFKC on just that scalar).
        var scalars = String.UnicodeScalarView()
        for s in out.unicodeScalars {
            if options.removeInvisibles, Self.invisibles.contains(s.value) {
                report.invisiblesRemoved += 1
                continue
            }
            if ArabicScript.isPresentationForm(s) {
                let base = String(s).precomposedStringWithCompatibilityMapping
                if (0xFEF5...0xFEFC).contains(s.value) { report.ligaturesSplit += 1 } else { report.presentationFormsMapped += 1 }
                scalars.append(contentsOf: base.unicodeScalars)
                continue
            }
            scalars.append(s)
        }
        out = String(scalars)

        if options.removeTatweel {
            let before = out.unicodeScalars.count
            out = String(String.UnicodeScalarView(out.unicodeScalars.filter { $0 != ArabicScript.tatweel }))
            report.tatweelRemoved = before - out.unicodeScalars.count
        }
        if options.collapseSpaces {
            out = out.components(separatedBy: "\n").map { line in
                line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            }.joined(separator: "\n")
        }
        return (out, report)
    }

    // MARK: Reversal detection

    /// Collects evidence from letter shapes, impossible letter positions and the lexicon.
    public func reversalEvidence(_ text: String) -> ReversalEvidence {
        var e = ReversalEvidence()
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        for word in words {
            let scalars = word.unicodeScalars.filter { ArabicScript.isArabicLetter($0) }
            guard let first = scalars.first, let last = scalars.last else { continue }

            // 1. Presentation-form shapes say exactly where a letter sits in its word.
            let fShape = Self.shape(first), lShape = Self.shape(last)
            if scalars.count > 1 {
                if fShape == .final || lShape == .initial { e.reversed += 1.5 }
                if fShape == .initial || lShape == .final { e.logical += 1.5 }
            }

            // 2. Letters that never start a word, after mapping shapes to base letters.
            let base = Self.baseLetters(word)
            guard base.count > 1 else { continue }
            if let b = base.first, b == "ة" || b == "ى" { e.reversed += 1 }
            if let b = base.last, b == "ة" || b == "ى" { e.logical += 1 }
            if base.hasPrefix("ال") && base.count > 3 { e.logical += 0.5 }
            if base.hasSuffix("لا") && base.count > 3 { e.reversed += 0.3 }

            // 3. Lexicon: does the word or its mirror image exist?
            let mirrored = String(base.reversed())
            if data.isKnownArabic(base) || (base.hasPrefix("ال") && data.isKnownArabic(String(base.dropFirst(2)))) {
                e.logical += 1
            }
            if mirrored != base, data.isKnownArabic(mirrored)
                || (mirrored.hasPrefix("ال") && data.isKnownArabic(String(mirrored.dropFirst(2)))) {
                e.reversed += 1
            }
        }
        return e
    }

    enum Shape { case isolated, initial, medial, final, none }

    static func shape(_ s: Unicode.Scalar) -> Shape {
        guard ArabicScript.isPresentationForm(s), let name = s.properties.name else { return .none }
        if name.hasSuffix("INITIAL FORM") { return .initial }
        if name.hasSuffix("MEDIAL FORM") { return .medial }
        if name.hasSuffix("FINAL FORM") { return .final }
        if name.hasSuffix("ISOLATED FORM") { return .isolated }
        return .none
    }

    /// Base letters only (presentation forms mapped, tashkeel and tatweel dropped).
    static func baseLetters(_ word: String) -> String {
        var out = String.UnicodeScalarView()
        for s in word.unicodeScalars {
            if ArabicScript.isTashkeel(s) || s == ArabicScript.tatweel { continue }
            if ArabicScript.isPresentationForm(s) {
                for b in String(s).precomposedStringWithCompatibilityMapping.unicodeScalars where ArabicScript.isArabicLetter(b) {
                    out.append(b)
                }
            } else if ArabicScript.isArabicLetter(s) {
                out.append(s)
            }
        }
        return String(out)
    }

    // MARK: Visual to logical order

    /// Reverses a visually ordered right-to-left line, keeping left-to-right runs (numbers, Latin) intact
    /// and mirroring brackets.
    public static func visualToLogical(_ line: String) -> String {
        var chars = Array(line.reversed())
        var i = 0
        while i < chars.count {
            if isLTR(chars[i]) {
                var j = i
                while j + 1 < chars.count, isLTR(chars[j + 1]) || (isLTRJoiner(chars[j + 1]) && j + 2 < chars.count && isLTR(chars[j + 2])) {
                    j += 1
                }
                chars[i...j].reverse()
                i = j + 1
            } else {
                if let m = mirror[chars[i]] { chars[i] = m }
                i += 1
            }
        }
        return String(chars)
    }

    private static func isLTR(_ c: Character) -> Bool {
        guard let s = c.unicodeScalars.first else { return false }
        return ArabicScript.isLatinLetter(s) || ArabicScript.isWesternDigit(s)
            || ArabicScript.isArabicIndicDigit(s) || ArabicScript.isPersianDigit(s)
    }

    /// Characters that stay inside a left-to-right run when they sit between two LTR characters (3.5, 10:30, a-b, 1/2).
    private static func isLTRJoiner(_ c: Character) -> Bool {
        ".,:/-_' %@".contains(c) || c == "\u{066B}" || c == "\u{066C}"
    }

    private static let mirror: [Character: Character] = ["(": ")", ")": "(", "[": "]", "]": "[", "{": "}", "}": "{",
                                                         "<": ">", ">": "<", "«": "»", "»": "«"]

    private static let invisibles: Set<UInt32> = [0xFEFF, 0x200B, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x00AD]
}
