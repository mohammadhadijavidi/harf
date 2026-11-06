import Foundation

/// A tiny, dependency-free check for "does this look like English?".
///
/// Used only to choose a direction or layout. It combines a short list of very common English words
/// with how pronounceable each word is (vowels present, no long consonant runs).
public enum EnglishHeuristics {
    static let common: Set<String> = [
        "a", "about", "after", "again", "all", "also", "am", "an", "and", "any", "are", "as", "at", "back",
        "be", "because", "been", "before", "best", "better", "but", "by", "call", "can", "come", "could",
        "day", "did", "do", "does", "done", "down", "each", "email", "even", "every", "file", "find", "first",
        "for", "from", "get", "give", "go", "good", "great", "had", "has", "have", "he", "hello", "help", "her",
        "here", "hi", "him", "his", "home", "how", "i", "if", "in", "into", "is", "it", "its", "just", "know",
        "last", "let", "like", "look", "make", "many", "me", "meeting", "more", "most", "my", "need", "new",
        "next", "no", "not", "now", "of", "off", "ok", "okay", "on", "one", "only", "or", "other", "our", "out",
        "over", "please", "project", "right", "said", "same", "see", "send", "she", "should", "so", "some",
        "soon", "still", "such", "take", "team", "than", "thank", "thanks", "that", "the", "their", "them",
        "then", "there", "these", "they", "thing", "think", "this", "time", "to", "today", "tomorrow", "too",
        "two", "up", "us", "use", "very", "want", "was", "way", "we", "week", "well", "were", "what", "when",
        "where", "which", "who", "why", "will", "with", "work", "world", "would", "yes", "you", "your",
    ]

    public static func score(_ text: String) -> Double {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
            .filter { $0.unicodeScalars.allSatisfy { $0.isASCII } }
        guard !words.isEmpty else { return 0 }
        var total = 0.0
        for w in words {
            if common.contains(w) { total += 1; continue }
            total += pronounceability(w) * 0.6
        }
        return total / Double(words.count)
    }

    /// 1 for words with a natural vowel/consonant mix, 0 for keyboard noise like "hgsghl".
    static func pronounceability(_ w: String) -> Double {
        guard w.count >= 2 else { return 0.3 }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var run = 0
        var longest = 0
        var vowelCount = 0
        for c in w {
            if vowels.contains(c) { vowelCount += 1; run = 0 } else { run += 1; longest = max(longest, run) }
        }
        let ratio = Double(vowelCount) / Double(w.count)
        if vowelCount == 0 || longest >= 4 { return 0 }
        if ratio < 0.2 || ratio > 0.8 { return 0.3 }
        return 1
    }
}
