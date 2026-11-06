import Foundation

/// One piece of transliterated text: a word, a phrase, or untouched text such as spaces and URLs.
public struct ArabiziSegment: Sendable, Equatable, Identifiable {
    public enum Source: String, Sendable, Equatable {
        /// Found in the curated Arabizi dictionary.
        case dictionary
        /// Built by the rule engine and confirmed by the Arabic lexicon.
        case lexicon
        /// Built by the rule engine only (a best guess).
        case rules
        /// Copied through (spaces, punctuation, numbers, URLs, acronyms).
        case passthrough
    }

    public let id: Int
    /// The original Latin text this segment covers.
    public let source: String
    public let origin: Source
    /// Arabic candidates, best first. Never empty.
    public let candidates: [String]
    /// Index into `candidates` of the chosen output.
    public var selection: Int

    public init(id: Int, source: String, origin: Source, candidates: [String], selection: Int = 0) {
        precondition(!candidates.isEmpty)
        self.id = id
        self.source = source
        self.origin = origin
        self.candidates = candidates
        self.selection = min(max(0, selection), candidates.count - 1)
    }

    public var output: String { candidates[selection] }
    public var isWord: Bool { origin != .passthrough }
    /// True when the user may want to pick a different spelling.
    public var isAmbiguous: Bool { isWord && candidates.count > 1 }
}

/// The result of transliterating a whole text.
public struct ArabiziResult: Sendable, Equatable {
    public var segments: [ArabiziSegment]

    public init(segments: [ArabiziSegment]) { self.segments = segments }

    public var text: String { segments.map(\.output).joined() }

    public var ambiguousSegments: [ArabiziSegment] { segments.filter(\.isAmbiguous) }

    public var wordCount: Int { segments.filter(\.isWord).count }

    /// Share of word segments that came from the dictionary or were confirmed by the lexicon.
    public var confidence: Double {
        let words = segments.filter(\.isWord)
        guard !words.isEmpty else { return 0 }
        let known = words.filter { $0.origin == .dictionary || $0.origin == .lexicon }.count
        return Double(known) / Double(words.count)
    }

    /// Returns a copy with a different candidate chosen for one segment.
    public func selecting(_ candidateIndex: Int, forSegment id: Int) -> ArabiziResult {
        var copy = self
        if let i = copy.segments.firstIndex(where: { $0.id == id }) {
            copy.segments[i].selection = min(max(0, candidateIndex), copy.segments[i].candidates.count - 1)
        }
        return copy
    }
}
