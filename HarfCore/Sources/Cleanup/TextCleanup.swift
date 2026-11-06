import Foundation

/// Digit systems used with Arabic script.
public enum DigitStyle: String, CaseIterable, Sendable, Identifiable {
    /// Leave digits as they are.
    case keep
    /// 0123456789
    case western
    /// ٠١٢٣٤٥٦٧٨٩ (U+0660–U+0669)
    case arabicIndic
    /// ۰۱۲۳۴۵۶۷۸۹ (U+06F0–U+06F9), also used for Urdu
    case persian

    public var id: String { rawValue }

    var zero: UInt32? {
        switch self {
        case .keep: return nil
        case .western: return 0x30
        case .arabicIndic: return 0x0660
        case .persian: return 0x06F0
        }
    }
}

/// Cleans Arabic text: tashkeel, tatweel, letter normalization and digits.
public struct TextCleanup: Sendable {
    public struct Options: Sendable, Equatable {
        /// Remove harakat, tanween, shadda, sukun and Quranic marks.
        public var removeTashkeel = true
        /// Remove the kashida / tatweel (ـ).
        public var removeTatweel = true
        /// أ إ آ ٱ -> ا
        public var normalizeAlef = false
        /// ى -> ي
        public var normalizeAlefMaqsura = false
        /// ة -> ه
        public var normalizeTaMarbuta = false
        /// ؤ -> و, ئ -> ي
        public var normalizeHamza = false
        /// Persian ک ی and Urdu ہ -> Arabic ك ي ه
        public var unifyPersianLetters = false
        public var digits: DigitStyle = .keep
        /// Collapse runs of spaces and trim trailing spaces on each line.
        public var tidyWhitespace = true

        public init() {}

        /// Strong normalization for search indexes and comparisons.
        public static var searchNormalization: Options {
            var o = Options()
            o.normalizeAlef = true
            o.normalizeAlefMaqsura = true
            o.normalizeTaMarbuta = true
            o.normalizeHamza = true
            o.unifyPersianLetters = true
            return o
        }
    }

    public struct Report: Sendable, Equatable {
        public var marksRemoved = 0
        public var lettersNormalized = 0
        public var digitsConverted = 0
        public var changedAnything: Bool { marksRemoved + lettersNormalized + digitsConverted > 0 }
    }

    public init() {}

    public func clean(_ text: String, options: Options = Options()) -> (text: String, report: Report) {
        var report = Report()
        var out = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            if options.removeTashkeel, ArabicScript.isTashkeel(s) { report.marksRemoved += 1; continue }
            if options.removeTatweel, s == ArabicScript.tatweel { report.marksRemoved += 1; continue }
            if let mapped = normalized(s, options) {
                report.lettersNormalized += 1
                out.append(mapped)
                continue
            }
            if let zero = options.digits.zero, let value = Self.digitValue(s), s.value != zero + value,
               let target = Unicode.Scalar(zero + value) {
                report.digitsConverted += 1
                out.append(target)
                continue
            }
            out.append(s)
        }
        var result = String(out)
        if options.tidyWhitespace {
            result = result.components(separatedBy: "\n").map { line -> String in
                var l = line
                while l.contains("  ") { l = l.replacingOccurrences(of: "  ", with: " ") }
                while l.hasSuffix(" ") { l.removeLast() }
                return l
            }.joined(separator: "\n")
        }
        return (result, report)
    }

    public func convertDigits(_ text: String, to style: DigitStyle) -> String {
        var o = Options()
        o.removeTashkeel = false
        o.removeTatweel = false
        o.tidyWhitespace = false
        o.digits = style
        return clean(text, options: o).text
    }

    public func removeTashkeel(_ text: String) -> String {
        var o = Options()
        o.removeTatweel = false
        o.tidyWhitespace = false
        return clean(text, options: o).text
    }

    static func digitValue(_ s: Unicode.Scalar) -> UInt32? {
        switch s.value {
        case 0x30...0x39: return s.value - 0x30
        case 0x0660...0x0669: return s.value - 0x0660
        case 0x06F0...0x06F9: return s.value - 0x06F0
        default: return nil
        }
    }

    private func normalized(_ s: Unicode.Scalar, _ o: Options) -> Unicode.Scalar? {
        switch s.value {
        case 0x0622, 0x0623, 0x0625, 0x0671: return o.normalizeAlef ? "\u{0627}" : nil
        case 0x0649: return o.normalizeAlefMaqsura ? "\u{064A}" : nil
        case 0x0629: return o.normalizeTaMarbuta ? "\u{0647}" : nil
        case 0x0624: return o.normalizeHamza ? "\u{0648}" : nil
        case 0x0626: return o.normalizeHamza ? "\u{064A}" : nil
        case 0x06A9: return o.unifyPersianLetters ? "\u{0643}" : nil
        case 0x06CC: return o.unifyPersianLetters ? "\u{064A}" : nil
        case 0x06C1: return o.unifyPersianLetters ? "\u{0647}" : nil
        default: return nil
        }
    }
}
