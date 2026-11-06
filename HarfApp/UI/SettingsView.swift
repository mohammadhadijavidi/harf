import SwiftUI
import HarfCore

struct SettingsView: View {
    @Bindable var model: AppModel
    var axTrusted: Bool

    var body: some View {
        let loc = model.localizer
        TabView {
            general(loc)
                .tabItem { Label(loc("General"), systemImage: "gearshape") }
            shortcuts(loc)
                .tabItem { Label(loc("Shortcuts"), systemImage: "command") }
            privacy(loc)
                .tabItem { Label(loc("Privacy"), systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 400)
        .environment(\.loc, loc)
        .environment(\.layoutDirection, loc.layoutDirection)
    }

    private func general(_ loc: Localizer) -> some View {
        Form {
            Picker(loc("Language"), selection: $model.language) {
                Text(loc("System")).tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "العربية").tag(AppLanguage.arabic)
            }
            Toggle(loc("Keep a local history of conversions"), isOn: $model.historyEnabled)
            Button(loc("Clear history"), role: .destructive) { model.clearHistory() }
                .disabled(model.history.isEmpty)
            Section {
                Toggle(loc("Offer on-device refinement for Arabizi"), isOn: $model.refineEnabled)
                Text(refineStatus(loc))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func refineStatus(_ loc: Localizer) -> String {
        switch OnDeviceRefiner.availability {
        case .available: return loc("Apple's on-device model is available. Text never leaves your Mac.")
        case .unsupportedSystem: return loc("Needs macOS 26 with Apple Intelligence. Harf uses its rule-based engine.")
        case .modelUnavailable: return loc("Apple Intelligence is off or still downloading. Harf uses its rule-based engine.")
        }
    }

    private func shortcuts(_ loc: Localizer) -> some View {
        Form {
            Toggle(loc("Enable global shortcuts"), isOn: $model.hotkeysEnabled)
            Section(loc("Shortcuts work on the selected text in any app")) {
                ForEach(QuickAction.allCases) { action in
                    HStack {
                        Text(loc(action.titleKey))
                        Spacer()
                        KeyCaps(keys: action.keyCaps)
                    }
                }
            }
            Section {
                HStack {
                    Image(systemName: axTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(axTrusted ? .green : .orange)
                    Text(axTrusted ? loc("Accessibility access granted") : loc("Needs Accessibility access"))
                    Spacer()
                    Button(loc("Open Accessibility Settings")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text(loc("Harf copies the selection, converts it and pastes the result. Your clipboard is restored afterwards."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func privacy(_ loc: Localizer) -> some View {
        Form {
            Section {
                Label(loc("No network access. No analytics. No accounts."), systemImage: "wifi.slash")
                Label(loc("Text is processed in memory on this Mac."), systemImage: "cpu")
                Label(loc("History is stored only in this Mac's preferences and can be turned off."), systemImage: "clock.arrow.circlepath")
            }
            Section {
                Text(verbatim: "Harf 1.0 · MIT License · Mohammad Hadi Javidi")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
