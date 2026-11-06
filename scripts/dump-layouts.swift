// Dumps the real macOS Arabic keyboard layouts (as shipped by Apple) using UCKeyTranslate.
// Harf's KeyboardLayoutTables.swift is generated from this output, so the mapping matches
// what macOS actually types, key for key.
//
//   swift scripts/dump-layouts.swift > layouts.json
//
import Carbon
import Foundation

func source(_ id: String) -> TISInputSource? {
    let props = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(props, true)?.takeRetainedValue() as? [TISInputSource] else { return nil }
    return list.first
}

func translate(_ src: TISInputSource, keyCode: UInt16, shift: Bool) -> String {
    guard let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return "" }
    let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
    return data.withUnsafeBytes { raw -> String in
        guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return "" }
        var dead: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        let mods: UInt32 = shift ? 0x02 : 0x00
        let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), mods,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                    &dead, chars.count, &length, &chars)
        return status == noErr ? String(utf16CodeUnits: chars, count: length) : ""
    }
}

// All character-producing key codes on an ANSI/ISO Mac keyboard.
let keyCodes: [UInt16] = Array(0...50).filter { ![36, 48, 49].contains($0) }

var allIDs: [String] = []
if let all = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] {
    for s in all {
        if let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) {
            let id = Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
            if id.localizedCaseInsensitiveContains("arab") || id.hasSuffix(".US") { allIDs.append(id) }
        }
    }
}

var out: [String: Any] = ["available": allIDs.sorted()]
for id in ["com.apple.keylayout.US", "com.apple.keylayout.Arabic", "com.apple.keylayout.ArabicPC",
           "com.apple.keylayout.Arabic-QWERTY", "com.apple.keylayout.Arabic-AZERTY"] {
    guard let s = source(id) else { out[id] = NSNull(); continue }
    var rows: [[String: Any]] = []
    for k in keyCodes {
        rows.append(["key": Int(k), "plain": translate(s, keyCode: k, shift: false),
                     "shift": translate(s, keyCode: k, shift: true)])
    }
    out[id] = rows
}
let json = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(json)
