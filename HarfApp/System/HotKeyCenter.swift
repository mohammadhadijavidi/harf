import Carbon
import AppKit

/// What a global shortcut does.
enum QuickAction: String, CaseIterable, Identifiable {
    case smart, arabizi, layout, pdfRepair, cleanup
    var id: String { rawValue }

    /// Carbon virtual key code and display key.
    var key: (code: UInt32, label: String) {
        switch self {
        case .smart: return (UInt32(kVK_Space), "Space")
        case .arabizi: return (UInt32(kVK_ANSI_A), "A")
        case .layout: return (UInt32(kVK_ANSI_K), "K")
        case .pdfRepair: return (UInt32(kVK_ANSI_P), "P")
        case .cleanup: return (UInt32(kVK_ANSI_T), "T")
        }
    }

    var titleKey: String {
        switch self {
        case .smart: return "Smart fix"
        case .arabizi: return "Arabizi"
        case .layout: return "Keyboard Layout"
        case .pdfRepair: return "PDF Repair"
        case .cleanup: return "Cleanup"
        }
    }

    var keyCaps: [String] { ["⌃", "⌥", key.label] }
}

/// Registers system-wide shortcuts with Carbon's RegisterEventHotKey (no Accessibility needed to register;
/// Accessibility is needed later to copy and paste the selection).
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var handler: ((QuickAction) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x4841_5246 // "HARF"

    func registerAll() {
        unregisterAll()
        installHandlerIfNeeded()
        for (index, action) in QuickAction.allCases.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(action.key.code, UInt32(controlKey | optionKey), id,
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
        }
    }

    func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        let all = QuickAction.allCases
        let index = Int(id) - 1
        guard index >= 0, index < all.count else { return }
        handler?(all[index])
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let id = hotKeyID.id
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated { HotKeyCenter.shared.fire(id: id) }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
