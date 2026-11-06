import Foundation

/// The four tools Harf offers.
public enum HarfMode: String, CaseIterable, Sendable, Identifiable, Codable {
    case arabizi
    case layout
    case pdfRepair
    case cleanup

    public var id: String { rawValue }
}

/// All options for all modes, so a single value can be stored and passed around.
public struct HarfOptions: Sendable, Equatable {
    public var layoutDirection: ConversionDirection? = nil   // nil = automatic
    public var keyboardLayout: KeyboardLayout? = nil     // nil = automatic
    public var pdf = PDFTextRepair.Options()
    public var cleanup = TextCleanup.Options()
    public init() {}
}

/// A short machine-readable note about what the engine did, shown in the UI status line.
public enum HarfNote: Sendable, Equatable, Hashable {
    case arabiziConfidence(percent: Int)
    case ambiguousWords(Int)
    case layoutDetected(direction: ConversionDirection, layout: KeyboardLayout)
    case reversedOrderFixed(lines: Int)
    case presentationFormsMapped(Int)
    case ligaturesSplit(Int)
    case tatweelRemoved(Int)
    case marksRemoved(Int)
    case lettersNormalized(Int)
    case digitsConverted(Int)
    case nothingToChange
}

/// The outcome of one transformation.
public struct HarfResult: Sendable, Equatable {
    public var mode: HarfMode
    public var output: String
    /// Only for Arabizi: word-level segments with alternatives.
    public var arabizi: ArabiziResult?
    public var notes: [HarfNote]

    public init(mode: HarfMode, output: String, arabizi: ArabiziResult? = nil, notes: [HarfNote] = []) {
        self.mode = mode
        self.output = output
        self.arabizi = arabizi
        self.notes = notes
    }
}

/// Entry point used by the app, the Services menu and the global hotkey.
public struct HarfEngine: Sendable {
    public let data: LanguageData
    public let arabizi: ArabiziTransliterator
    public let layout: KeyboardLayoutConverter
    public let pdf: PDFTextRepair
    public let cleanup: TextCleanup

    public init(data: LanguageData = .shared) {
        self.data = data
        self.arabizi = ArabiziTransliterator(data: data)
        self.layout = KeyboardLayoutConverter(data: data)
        self.pdf = PDFTextRepair(data: data)
        self.cleanup = TextCleanup()
    }

    public func transform(_ text: String, mode: HarfMode, options: HarfOptions = HarfOptions()) -> HarfResult {
        switch mode {
        case .arabizi:
            let r = arabizi.transliterate(text)
            var notes: [HarfNote] = []
            if r.wordCount > 0 { notes.append(.arabiziConfidence(percent: Int((r.confidence * 100).rounded()))) }
            if !r.ambiguousSegments.isEmpty { notes.append(.ambiguousWords(r.ambiguousSegments.count)) }
            return HarfResult(mode: mode, output: r.text, arabizi: r, notes: notes)

        case .layout:
            let c = layout.convert(text, direction: options.layoutDirection, layout: options.keyboardLayout)
            let notes: [HarfNote] = c.output == text ? [.nothingToChange] : [.layoutDetected(direction: c.direction, layout: c.layout)]
            return HarfResult(mode: mode, output: c.output, notes: notes)

        case .pdfRepair:
            let (out, report) = pdf.repair(text, options: options.pdf)
            var notes: [HarfNote] = []
            if report.reversedLines > 0 { notes.append(.reversedOrderFixed(lines: report.reversedLines)) }
            if report.presentationFormsMapped > 0 { notes.append(.presentationFormsMapped(report.presentationFormsMapped)) }
            if report.ligaturesSplit > 0 { notes.append(.ligaturesSplit(report.ligaturesSplit)) }
            if report.tatweelRemoved > 0 { notes.append(.tatweelRemoved(report.tatweelRemoved)) }
            if notes.isEmpty && out == text { notes.append(.nothingToChange) }
            return HarfResult(mode: mode, output: out, notes: notes)

        case .cleanup:
            let (out, report) = cleanup.clean(text, options: options.cleanup)
            var notes: [HarfNote] = []
            if report.marksRemoved > 0 { notes.append(.marksRemoved(report.marksRemoved)) }
            if report.lettersNormalized > 0 { notes.append(.lettersNormalized(report.lettersNormalized)) }
            if report.digitsConverted > 0 { notes.append(.digitsConverted(report.digitsConverted)) }
            if notes.isEmpty && out == text { notes.append(.nothingToChange) }
            return HarfResult(mode: mode, output: out, notes: notes)
        }
    }

    /// Detects the most likely tool for a text and transforms it with that tool.
    public func smartTransform(_ text: String, options: HarfOptions = HarfOptions()) -> (detection: ModeDetection, result: HarfResult) {
        let detection = ModeDetector(engine: self).detect(text)
        var opts = options
        if detection.mode == .layout, let dir = detection.layoutDirection { opts.layoutDirection = dir }
        return (detection, transform(text, mode: detection.mode, options: opts))
    }
}
