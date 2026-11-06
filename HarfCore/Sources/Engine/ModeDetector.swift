import Foundation

/// Why the detector picked a mode. Shown to the user so the choice is never a mystery.
public enum DetectionReason: String, Sendable, Equatable {
    case presentationForms
    case reversedOrder
    case wrongLayoutLatin      // Latin keyboard noise that reads as Arabic on an Arabic layout
    case wrongLayoutArabic     // Arabic keyboard noise that reads as English on the US layout
    case arabiziPattern        // digit letters or dictionary words
    case arabicText            // regular Arabic: cleanup is the useful tool
    case looksLikeEnglish      // plain English: nothing to do
    case fallback
}

public struct ModeDetection: Sendable, Equatable {
    public let mode: HarfMode
    public let reason: DetectionReason
    public let layoutDirection: ConversionDirection?
    /// 0...1, how sure the detector is. A heuristic score, not a probability.
    public let confidence: Double

    /// False when the text already looks fine (plain English), so a one-shot action should leave it alone.
    public var shouldTransform: Bool { reason != .looksLikeEnglish }
}

/// Picks the right tool for a piece of text using cheap, explainable signals.
public struct ModeDetector: Sendable {
    let engine: HarfEngine

    public init(engine: HarfEngine) { self.engine = engine }

    public func detect(_ text: String) -> ModeDetection {
        let counts = ArabicScript.counts(text)
        guard counts.total > 0 else {
            return ModeDetection(mode: .cleanup, reason: .fallback, layoutDirection: nil, confidence: 0.2)
        }

        if counts.presentationForms > 0 {
            return ModeDetection(mode: .pdfRepair, reason: .presentationForms, layoutDirection: nil, confidence: 0.95)
        }

        if counts.arabicRatio >= 0.5 {
            let evidence = engine.pdf.reversalEvidence(text)
            if evidence.isReversed && evidence.reversed >= evidence.logical * 1.5 {
                return ModeDetection(mode: .pdfRepair, reason: .reversedOrder, layoutDirection: nil, confidence: 0.75)
            }
            let arabicKnown = engine.layout.arabicScore(text)
            let asLatin = engine.layout.convert(text, direction: .toLatin)
            if asLatin.recognisedRatio >= 0.5 && arabicKnown < 0.35 {
                return ModeDetection(mode: .layout, reason: .wrongLayoutArabic, layoutDirection: .toLatin,
                                     confidence: min(1, asLatin.recognisedRatio))
            }
            return ModeDetection(mode: .cleanup, reason: .arabicText, layoutDirection: nil, confidence: 0.6)
        }

        // Latin text: Arabizi, or Arabic typed on the US layout?
        let asArabic = engine.layout.convert(text, direction: .toArabic)
        let arabizi = arabiziScore(text)
        let english = EnglishHeuristics.score(text)
        if asArabic.recognisedRatio >= 0.4 && asArabic.recognisedRatio > arabizi {
            return ModeDetection(mode: .layout, reason: .wrongLayoutLatin, layoutDirection: .toArabic,
                                 confidence: min(1, asArabic.recognisedRatio))
        }
        if arabizi >= 0.25 || arabizi >= english {
            return ModeDetection(mode: .arabizi, reason: .arabiziPattern, layoutDirection: nil,
                                 confidence: min(1, max(arabizi, 0.3)))
        }
        if english >= 0.5 {
            return ModeDetection(mode: .arabizi, reason: .looksLikeEnglish, layoutDirection: nil, confidence: min(1, english))
        }
        return ModeDetection(mode: .arabizi, reason: .fallback, layoutDirection: nil, confidence: 0.2)
    }

    /// Share of Latin words that are Arabizi dictionary words or use digit letters (3, 7, 2, ...).
    func arabiziScore(_ text: String) -> Double {
        let words = text.split(whereSeparator: { $0.isWhitespace || ($0.isPunctuation && $0 != "'") })
            .map { LanguageData.fold(String($0)) }
            .filter { $0.contains(where: \.isLetter) }
        guard !words.isEmpty else { return 0 }
        var hits = 0.0
        for w in words {
            if engine.data.arabizi[w] != nil { hits += 1; continue }
            let hasLetterDigit = w.contains { "2356789".contains($0) } && w.contains(where: \.isLetter)
            if hasLetterDigit { hits += 1 }
        }
        return hits / Double(words.count)
    }
}
