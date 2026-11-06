import AppKit
import SwiftUI
import HarfCore

/// Runs quick actions from the global shortcuts, the Services menu and the menu bar.
@MainActor
final class QuickActionRunner {
    let model: AppModel
    private let selection = SelectionTransformer()
    private let hud = HUDController()

    init(model: AppModel) { self.model = model }

    /// Transforms a string with an action. Returns nil when there is nothing to change.
    func apply(_ action: QuickAction, to text: String) -> (mode: HarfMode, output: String)? {
        let engine = model.engine
        let result: HarfResult
        switch action {
        case .smart:
            let (detection, r) = engine.smartTransform(text, options: model.options)
            guard detection.shouldTransform else { return nil }
            result = r
        case .arabizi: result = engine.transform(text, mode: .arabizi, options: model.options)
        case .layout:
            var o = model.options
            o.layoutDirection = nil
            o.keyboardLayout = nil
            result = engine.transform(text, mode: .layout, options: o)
        case .pdfRepair: result = engine.transform(text, mode: .pdfRepair, options: model.options)
        case .cleanup: result = engine.transform(text, mode: .cleanup, options: model.options)
        }
        return result.output == text ? nil : (result.mode, result.output)
    }

    /// Global shortcut: transform the selection in the frontmost app.
    func runOnSelection(_ action: QuickAction) {
        Task {
            var produced: (mode: HarfMode, output: String)?
            let outcome = await selection.run { text in
                produced = self.apply(action, to: text)
                return produced?.output
            }
            let loc = model.localizer
            switch outcome {
            case .replaced(let input, let output):
                model.record(origin: "hotkey", mode: produced?.mode, input: input, output: output)
                hud.show(symbol: (produced?.mode ?? .arabizi).symbol,
                         title: loc(produced?.mode.titleKey ?? action.titleKey), detail: output, loc: loc)
            case .unchanged:
                hud.show(symbol: "checkmark.circle", title: loc("Nothing to change"), detail: nil, loc: loc)
            case .noSelection:
                hud.show(symbol: "text.cursor", title: loc("Select some text first"), detail: nil, loc: loc)
            case .needsAccessibility:
                hud.show(symbol: "lock.shield", title: loc("Allow Harf in Accessibility settings"), detail: nil, loc: loc)
            }
        }
    }

    /// Menu bar: transform whatever is on the clipboard and put the result back.
    @discardableResult
    func runOnClipboard(_ action: QuickAction) -> String? {
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string), !text.isEmpty else { return nil }
        guard let r = apply(action, to: text) else { return text }
        pb.clearContents()
        pb.setString(r.output, forType: .string)
        model.record(origin: "menu", mode: r.mode, input: text, output: r.output)
        return r.output
    }
}

/// Services menu provider. Selectors match the NSMessage values in Info.plist.
@MainActor
final class ServiceProvider: NSObject {
    let runner: QuickActionRunner

    init(runner: QuickActionRunner) { self.runner = runner }

    @objc func harfSmart(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.smart, pboard, error)
    }
    @objc func harfArabizi(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.arabizi, pboard, error)
    }
    @objc func harfLayout(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.layout, pboard, error)
    }
    @objc func harfPDF(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.pdfRepair, pboard, error)
    }
    @objc func harfCleanup(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.cleanup, pboard, error)
    }

    private func handle(_ action: QuickAction, _ pboard: NSPasteboard, _ error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else {
            error.pointee = "No text was sent to Harf." as NSString
            return
        }
        let output = runner.apply(action, to: text)?.output ?? text
        pboard.clearContents()
        pboard.setString(output, forType: .string)
        if output != text { runner.model.record(origin: "service", input: text, output: output) }
    }
}

/// A small floating confirmation shown after a global shortcut.
@MainActor
final class HUDController {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(symbol: String, title: String, detail: String?, loc: Localizer) {
        let view = HUDView(symbol: symbol, title: title, detail: detail)
            .environment(\.layoutDirection, loc.layoutDirection)
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        let panel = self.panel ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .statusBar
            p.hasShadow = true
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            return p
        }()
        self.panel = panel
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - hosting.fittingSize.width / 2, y: f.minY + 120))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideTask?.cancel()
        hideTask = Task { [weak panel] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                panel?.animator().alphaValue = 0
            }, completionHandler: nil)
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
        }
    }
}

private struct HUDView: View {
    let symbol: String
    let title: String
    let detail: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.dark.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                if let detail {
                    Text(verbatim: detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.78)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
