import SwiftUI
import HarfCore

/// The interface language. "System" follows macOS; the other two override it inside the app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, arabic
    var id: String { rawValue }

    var resolvedCode: String {
        switch self {
        case .english: return "en"
        case .arabic: return "ar"
        case .system:
            let preferred = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("ar") ? "ar" : "en"
        }
    }
}

/// Looks strings up in the compiled String Catalog for one language, so the language can be switched
/// at runtime and screenshots can be rendered in both languages from one process.
struct Localizer {
    let code: String
    private let bundle: Bundle

    init(code: String) {
        self.code = code
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .main
        }
    }

    static let english = Localizer(code: "en")
    static let arabic = Localizer(code: "ar")

    var isRTL: Bool { code == "ar" }
    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
    var locale: Locale { Locale(identifier: code) }

    func callAsFunction(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: self(key), arguments: args)
    }
}

private struct LocalizerKey: EnvironmentKey { static let defaultValue = Localizer.english }

extension EnvironmentValues {
    var loc: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}

// MARK: - Display names for core types

extension HarfMode {
    var titleKey: String {
        switch self {
        case .arabizi: return "Arabizi"
        case .layout: return "Keyboard Layout"
        case .pdfRepair: return "PDF Repair"
        case .cleanup: return "Cleanup"
        }
    }

    var subtitleKey: String {
        switch self {
        case .arabizi: return "Franco-Arabic to Arabic script"
        case .layout: return "Text typed on the wrong layout"
        case .pdfRepair: return "Broken Arabic copied from PDFs"
        case .cleanup: return "Tashkeel, letters and digits"
        }
    }

    var headlineKey: String {
        switch self {
        case .arabizi: return "Write Arabizi, get real Arabic."
        case .layout: return "Forgot to switch the keyboard? Undo it."
        case .pdfRepair: return "Make PDF Arabic readable and searchable again."
        case .cleanup: return "Strip diacritics, normalize letters, convert digits."
        }
    }

    var symbol: String {
        switch self {
        case .arabizi: return "character.bubble"
        case .layout: return "keyboard"
        case .pdfRepair: return "doc.text.magnifyingglass"
        case .cleanup: return "wand.and.stars"
        }
    }

    var shortcutDigit: Character {
        switch self {
        case .arabizi: return "1"
        case .layout: return "2"
        case .pdfRepair: return "3"
        case .cleanup: return "4"
        }
    }

    var placeholderKey: String {
        switch self {
        case .arabizi: return "Type or paste Arabizi, for example: ana ra7 aroo7 el beit"
        case .layout: return "Paste text typed on the wrong keyboard, for example: hgsghl ugd;l"
        case .pdfRepair: return "Paste Arabic copied from a PDF that looks reversed or broken"
        case .cleanup: return "Paste Arabic text with tashkeel, tatweel or mixed digits"
        }
    }
}

extension HarfNote {
    func text(_ loc: Localizer) -> String {
        switch self {
        case .arabiziConfidence(let p): return loc.format("Known words: %d%%", p)
        case .ambiguousWords(let n): return loc.format("Words with alternatives: %d", n)
        case .layoutDetected(let dir, let layout):
            let d = dir == .toArabic ? loc("English keys to Arabic") : loc("Arabic keys to English")
            return d + " · " + loc(layout.displayName)
        case .reversedOrderFixed(let n): return loc.format("Reversed lines fixed: %d", n)
        case .presentationFormsMapped(let n): return loc.format("Presentation forms mapped: %d", n)
        case .ligaturesSplit(let n): return loc.format("Lam-alef ligatures split: %d", n)
        case .tatweelRemoved(let n): return loc.format("Tatweel removed: %d", n)
        case .marksRemoved(let n): return loc.format("Marks removed: %d", n)
        case .lettersNormalized(let n): return loc.format("Letters normalized: %d", n)
        case .digitsConverted(let n): return loc.format("Digits converted: %d", n)
        case .nothingToChange: return loc("Nothing to change")
        }
    }

    var symbol: String {
        switch self {
        case .arabiziConfidence: return "checkmark.seal"
        case .ambiguousWords: return "arrow.triangle.branch"
        case .layoutDetected: return "keyboard"
        case .reversedOrderFixed: return "arrow.left.arrow.right"
        case .presentationFormsMapped, .ligaturesSplit: return "textformat"
        case .tatweelRemoved, .marksRemoved: return "eraser"
        case .lettersNormalized: return "character"
        case .digitsConverted: return "number"
        case .nothingToChange: return "checkmark.circle"
        }
    }
}

extension DetectionReason {
    var key: String {
        switch self {
        case .presentationForms: return "This looks like Arabic copied from a PDF."
        case .reversedOrder: return "This Arabic looks reversed, as if copied from a PDF."
        case .wrongLayoutLatin: return "This looks like Arabic typed on an English keyboard."
        case .wrongLayoutArabic: return "This looks like English typed on an Arabic keyboard."
        case .arabiziPattern: return "This looks like Arabizi."
        case .arabicText: return "This is regular Arabic text."
        case .looksLikeEnglish: return "This looks like plain English."
        case .fallback: return "Not sure what this is."
        }
    }
}
