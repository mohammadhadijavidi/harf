import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Optional refinement of an Arabizi draft with Apple's on-device language model (macOS 26+,
/// Apple Intelligence enabled). Nothing leaves the Mac. When the model is missing, unavailable or
/// returns something implausible, the deterministic draft is kept.
public enum OnDeviceRefiner {
    public enum Availability: Sendable, Equatable {
        case available
        /// The OS or SDK is too old to have the FoundationModels framework.
        case unsupportedSystem
        /// The framework exists but the model cannot be used (Apple Intelligence off, not downloaded, device not eligible).
        case modelUnavailable(String)
    }

    public enum Outcome: Sendable, Equatable {
        /// The model produced a plausible refinement.
        case refined(String)
        /// The deterministic draft was kept, with the reason.
        case keptDraft(reason: String)
    }

    public static var availability: Availability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let state = SystemLanguageModel.default.availability
            if case .available = state { return .available }
            return .modelUnavailable(String(describing: state))
        }
        return .unsupportedSystem
        #else
        return .unsupportedSystem
        #endif
    }

    /// Asks the on-device model to fix spelling in the Arabic draft, using the Arabizi source for context.
    public static func refine(source: String, draft: String) async -> Outcome {
        guard availability == .available else { return .keptDraft(reason: "unavailable") }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let instructions = """
            You convert Arabizi (Arabic written with Latin letters and digits) into correct Arabic script.
            You receive the Arabizi source and a draft made by a rule-based converter.
            Fix spelling mistakes in the draft. Keep the same dialect, meaning and word order.
            Do not translate, explain, add or remove content. Reply with the corrected Arabic text only.
            """
            let prompt = "Arabizi source:\n\(source)\n\nDraft:\n\(draft)\n\nCorrected Arabic:"
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt, options: GenerationOptions(temperature: 0.1))
                return validate(response.content, draft: draft)
            } catch {
                return .keptDraft(reason: "error")
            }
        }
        #endif
        return .keptDraft(reason: "unavailable")
    }

    /// Rejects answers that are not mostly Arabic, change the length a lot, or add lines.
    public static func validate(_ answer: String, draft: String) -> Outcome {
        var text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        for q in ["\"", "«", "»", "“", "”", "`"] {
            if text.hasPrefix(q) { text.removeFirst() }
            if text.hasSuffix(q) { text.removeLast() }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .keptDraft(reason: "empty") }
        let counts = ArabicScript.counts(text)
        guard counts.total > 0, counts.arabicRatio >= 0.8 else { return .keptDraft(reason: "not-arabic") }
        let ratio = Double(text.count) / Double(max(1, draft.count))
        guard ratio >= 0.6, ratio <= 1.6 else { return .keptDraft(reason: "length") }
        let draftLines = draft.split(whereSeparator: \.isNewline).count
        let lines = text.split(whereSeparator: \.isNewline).count
        guard lines <= max(1, draftLines) else { return .keptDraft(reason: "lines") }
        return text == draft ? .keptDraft(reason: "unchanged") : .refined(text)
    }
}
