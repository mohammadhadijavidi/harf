import Foundation

/// Character classes and small helpers for Arabic script.
public enum ArabicScript {
    public static let tatweel: Unicode.Scalar = "\u{0640}"

    /// Base Arabic letters (including Persian/Urdu extensions) and presentation forms.
    public static func isArabicLetter(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x0621...0x063A, 0x0641...0x064A, 0x066E...0x066F, 0x0671...0x06D3, 0x06D5,
             0x06EE...0x06EF, 0x06FA...0x06FC, 0x06FF, 0x0750...0x077F:
            return true
        case 0xFB50...0xFDFF, 0xFE70...0xFEFC:
            return isPresentationForm(s) && s.properties.isAlphabetic
        default:
            return false
        }
    }

    /// Harakat, tanween, shadda, sukun, superscript alef and Quranic annotation marks.
    public static func isTashkeel(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x064B...0x065F, 0x0670, 0x06D6...0x06DC, 0x06DF...0x06E4, 0x06E7, 0x06E8, 0x06EA...0x06ED,
             0x08D3...0x08E1, 0x08E3...0x08FF:
            return true
        default:
            return false
        }
    }

    /// Arabic Presentation Forms-A (U+FB50–U+FDFF) and -B (U+FE70–U+FEFC).
    public static func isPresentationForm(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0xFB50...0xFDFF, 0xFE70...0xFEFC: return true
        default: return false
        }
    }

    public static func isLatinLetter(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F: return s.properties.isAlphabetic
        default: return false
        }
    }

    public static func isArabicIndicDigit(_ s: Unicode.Scalar) -> Bool { (0x0660...0x0669).contains(s.value) }
    public static func isPersianDigit(_ s: Unicode.Scalar) -> Bool { (0x06F0...0x06F9).contains(s.value) }
    public static func isWesternDigit(_ s: Unicode.Scalar) -> Bool { (0x30...0x39).contains(s.value) }

    /// Counts of letters per script.
    public struct ScriptCounts: Sendable, Equatable {
        public var arabic = 0
        public var latin = 0
        public var presentationForms = 0
        public var total: Int { arabic + latin }
        /// Share of Arabic letters among Arabic + Latin letters (0 when there are no letters).
        public var arabicRatio: Double { total == 0 ? 0 : Double(arabic) / Double(total) }
    }

    public static func counts(_ text: String) -> ScriptCounts {
        var c = ScriptCounts()
        for s in text.unicodeScalars {
            if isArabicLetter(s) {
                c.arabic += 1
                if isPresentationForm(s) { c.presentationForms += 1 }
            } else if isLatinLetter(s) {
                c.latin += 1
            }
        }
        return c
    }

    /// True when the text is predominantly Arabic script, so it should be shown right to left.
    public static func isPredominantlyRTL(_ text: String) -> Bool {
        let c = counts(text)
        return c.total > 0 && c.arabicRatio >= 0.5
    }

    /// Normal form used for dictionary lookups: no tashkeel or tatweel, unified alef/ya/ta marbuta.
    public static func lookupKey(_ word: String) -> String {
        var out = String.UnicodeScalarView()
        for s in word.unicodeScalars {
            if isTashkeel(s) || s == tatweel { continue }
            switch s.value {
            case 0x0622, 0x0623, 0x0625, 0x0671: out.append("\u{0627}")
            case 0x0649: out.append("\u{064A}")
            case 0x0629: out.append("\u{0647}")
            default: out.append(s)
            }
        }
        return String(out)
    }
}
