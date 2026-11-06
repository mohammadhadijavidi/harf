import SwiftUI
import AppKit
import Observation
import HarfCore

/// One entry in the local history.
struct HistoryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var mode: HarfMode
    var input: String
    var output: String
    /// Where it came from: workbench, hotkey, service, menu.
    var origin: String
}

/// State of the optional on-device refinement for Arabizi.
enum RefineState: Equatable {
    case idle
    case running
    case refined(String)
    case kept(String)   // reason key
}

@MainActor
@Observable
final class AppModel {
    let engine: HarfEngine

    private(set) var input: String = ""
    private(set) var mode: HarfMode = .arabizi
    private(set) var result: HarfResult
    private(set) var detection: ModeDetection?
    private var storedOptions = HarfOptions()
    var options: HarfOptions {
        get { storedOptions }
        set { storedOptions = newValue; recompute() }
    }
    private(set) var history: [HistoryItem] = []
    private(set) var refine: RefineState = .idle
    var lastCopiedAt: Date?

    /// Persisted preferences.
    private var storedHistoryEnabled: Bool
    private var storedRefineEnabled: Bool
    private var storedLanguage: AppLanguage
    private var storedHotkeysEnabled: Bool

    var historyEnabled: Bool {
        get { storedHistoryEnabled }
        set {
            storedHistoryEnabled = newValue
            if persist { defaults.set(newValue, forKey: Keys.history) }
            if !newValue { clearHistory() }
        }
    }
    var refineEnabled: Bool {
        get { storedRefineEnabled }
        set { storedRefineEnabled = newValue; if persist { defaults.set(newValue, forKey: Keys.refine) } }
    }
    var language: AppLanguage {
        get { storedLanguage }
        set { storedLanguage = newValue; if persist { defaults.set(newValue.rawValue, forKey: Keys.language) } }
    }
    var hotkeysEnabled: Bool {
        get { storedHotkeysEnabled }
        set {
            storedHotkeysEnabled = newValue
            if persist { defaults.set(newValue, forKey: Keys.hotkeys) }
            onHotkeysChanged?()
        }
    }

    @ObservationIgnored var onHotkeysChanged: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persist: Bool

    private enum Keys {
        static let history = "historyEnabled"
        static let refine = "refineEnabled"
        static let language = "appLanguage"
        static let hotkeys = "hotkeysEnabled"
        static let items = "historyItems"
        static let mode = "lastMode"
    }

    init(engine: HarfEngine = HarfEngine(), defaults: UserDefaults = .standard, persist: Bool = true) {
        self.engine = engine
        self.defaults = defaults
        self.persist = persist
        self.result = HarfResult(mode: .arabizi, output: "")
        self.storedHistoryEnabled = defaults.object(forKey: Keys.history) as? Bool ?? true
        self.storedRefineEnabled = defaults.object(forKey: Keys.refine) as? Bool ?? false
        self.storedLanguage = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        self.storedHotkeysEnabled = defaults.object(forKey: Keys.hotkeys) as? Bool ?? true
        if persist {
            if let raw = defaults.string(forKey: Keys.mode), let m = HarfMode(rawValue: raw) { mode = m }
            if let data = defaults.data(forKey: Keys.items),
               let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
                history = items
            }
        }
    }

    var localizer: Localizer { Localizer(code: language.resolvedCode) }

    // MARK: Editing

    func setInput(_ text: String) {
        guard text != input else { return }
        input = text
        refine = .idle
        recompute()
    }

    func setMode(_ newMode: HarfMode) {
        guard newMode != mode else { return }
        mode = newMode
        refine = .idle
        if persist { defaults.set(newMode.rawValue, forKey: Keys.mode) }
        recompute()
    }

    func chooseAlternative(_ index: Int, forSegment id: Int) {
        guard let a = result.arabizi else { return }
        let updated = a.selecting(index, forSegment: id)
        result.arabizi = updated
        result.output = updated.text
        refine = .idle
    }

    /// Output shown to the user (the refined text when refinement succeeded).
    var displayedOutput: String {
        if case .refined(let text) = refine { return text }
        return result.output
    }

    /// A mode suggestion when the detector disagrees with the current mode.
    var suggestion: ModeDetection? {
        guard let d = detection, d.mode != mode, d.shouldTransform, d.confidence >= 0.5 else { return nil }
        return d
    }

    func useOutputAsInput() {
        let out = displayedOutput
        guard !out.isEmpty else { return }
        setInput(out)
    }

    func clear() { setInput("") }

    private func recompute() {
        result = engine.transform(input, mode: mode, options: options)
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        detection = trimmed.count >= 3 ? ModeDetector(engine: engine).detect(input) : nil
    }

    // MARK: Refinement

    func runRefinement() {
        guard mode == .arabizi, !input.isEmpty, refine != .running else { return }
        refine = .running
        let source = input
        let draft = result.output
        Task { [weak self] in
            let outcome = await OnDeviceRefiner.refine(source: source, draft: draft)
            guard let self, self.input == source else { return }
            switch outcome {
            case .refined(let text): self.refine = .refined(text)
            case .keptDraft(let reason): self.refine = .kept(reason)
            }
        }
    }

    // MARK: History

    func record(origin: String, mode: HarfMode? = nil, input: String? = nil, output: String? = nil) {
        guard historyEnabled else { return }
        let item = HistoryItem(date: Date(), mode: mode ?? self.mode, input: input ?? self.input,
                               output: output ?? displayedOutput, origin: origin)
        guard !item.input.isEmpty, item.output != item.input else { return }
        if let first = history.first, first.input == item.input, first.mode == item.mode { history[0] = item } else { history.insert(item, at: 0) }
        if history.count > 60 { history.removeLast(history.count - 60) }
        saveHistory()
    }

    func restore(_ item: HistoryItem) {
        mode = item.mode
        input = item.input
        refine = .idle
        recompute()
    }

    func deleteHistory(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func seedHistory(_ items: [HistoryItem]) { history = items }

    private func saveHistory() {
        guard persist else { return }
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: Keys.items) }
    }

    // MARK: Clipboard

    func copyOutput() {
        let out = displayedOutput
        guard !out.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
        lastCopiedAt = Date()
        record(origin: "workbench")
    }

    func pasteInput() {
        if let s = NSPasteboard.general.string(forType: .string) { setInput(s) }
    }
}
