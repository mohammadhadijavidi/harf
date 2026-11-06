import AppKit
import ApplicationServices

/// Transforms the current selection in the frontmost app: copy, transform, paste, restore the clipboard.
///
/// Requires Accessibility permission (to post the Cmd-C and Cmd-V key events). The user's clipboard is
/// saved before and restored after, and the temporary items are marked transient so clipboard managers
/// can ignore them.
@MainActor
final class SelectionTransformer {
    enum Outcome: Equatable {
        case replaced(input: String, output: String)
        case unchanged
        case noSelection
        case needsAccessibility
    }

    static func isTrusted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    func run(_ transform: (String) -> String?) async -> Outcome {
        guard Self.isTrusted(prompt: false) else {
            _ = Self.isTrusted(prompt: true)
            return .needsAccessibility
        }
        let pb = NSPasteboard.general
        let saved = snapshot(pb)
        let before = pb.changeCount

        // Give the user a moment to release the shortcut keys so they don't mix with Cmd-C.
        try? await Task.sleep(for: .milliseconds(120))
        postKey(8) // C
        var copied = false
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(25))
            if pb.changeCount != before { copied = true; break }
        }
        guard copied, let text = pb.string(forType: .string), !text.isEmpty else {
            restore(saved, to: pb)
            return .noSelection
        }
        guard let output = transform(text), output != text else {
            restore(saved, to: pb)
            return .unchanged
        }
        pb.clearContents()
        pb.setString(output, forType: .string)
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        postKey(9) // V
        try? await Task.sleep(for: .milliseconds(350))
        restore(saved, to: pb)
        return .replaced(input: text, output: output)
    }

    private func postKey(_ code: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
    }

    private func snapshot(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pb.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
    }

    private func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to pb: NSPasteboard) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        let restored: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(restored)
    }
}
