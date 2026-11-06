import SwiftUI
import AppKit
import HarfCore

/// Entry point. `--render-assets <dir>` renders the README screenshots and exits; otherwise the app runs.
@main
enum HarfMain {
    @MainActor static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-assets") {
            let dir = i + 1 < args.count ? args[i + 1] : "renders"
            let app = NSApplication.shared
            app.setActivationPolicy(.prohibited)
            let ok = AssetRenderer.renderAll(to: URL(fileURLWithPath: dir))
            exit(ok ? 0 : 1)
        }
        HarfApp.main()
    }
}

/// Shared live state for the app scenes.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    let model = AppModel()
    lazy var runner = QuickActionRunner(model: model)
}

/// Polls Accessibility trust so the UI can show an accurate status.
@MainActor
@Observable
final class AccessibilityStatus {
    var trusted = SelectionTransformer.isTrusted(prompt: false)
    @ObservationIgnored private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                let now = SelectionTransformer.isTrusted(prompt: false)
                if self?.trusted != now { self?.trusted = now }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: ServiceProvider?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.shared
        let provider = ServiceProvider(runner: env.runner)
        services = provider
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()

        HotKeyCenter.shared.handler = { action in env.runner.runOnSelection(action) }
        env.model.onHotkeysChanged = {
            if env.model.hotkeysEnabled { HotKeyCenter.shared.registerAll() } else { HotKeyCenter.shared.unregisterAll() }
        }
        if env.model.hotkeysEnabled { HotKeyCenter.shared.registerAll() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct HarfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var ax = AccessibilityStatus()
    private let env = AppEnvironment.shared

    var body: some Scene {
        Window("Harf", id: "workbench") {
            WorkbenchView(model: env.model, axTrusted: ax.trusted)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear { ax.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
        .commands { HarfCommands(model: env.model) }

        MenuBarExtra {
            MenuBarContent(env: env, axTrusted: ax.trusted)
        } label: {
            Text(verbatim: "ح")
                .font(.system(size: 15, weight: .bold))
                .accessibilityLabel("Harf")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: env.model, axTrusted: ax.trusted)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    let env: AppEnvironment
    let axTrusted: Bool

    var body: some View {
        MenuBarPanel(model: env.model, axTrusted: axTrusted,
                     runClipboard: { env.runner.runOnClipboard($0) },
                     openWorkbench: {
                         openWindow(id: "workbench")
                         NSApp.activate()
                     },
                     openSettings: {
                         NSApp.activate()
                         openSettings()
                     },
                     quit: { NSApp.terminate(nil) })
    }
}

struct HarfCommands: Commands {
    let model: AppModel

    var body: some Commands {
        let loc = model.localizer
        CommandMenu(loc("Tools")) {
            ForEach(HarfMode.allCases) { mode in
                Button(loc(mode.titleKey)) { model.setMode(mode) }
                    .keyboardShortcut(KeyEquivalent(mode.shortcutDigit), modifiers: .command)
            }
            Divider()
            Button(loc("Copy result")) { model.copyOutput() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button(loc("Paste as input")) { model.pasteInput() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            Button(loc("Use result as input")) { model.useOutputAsInput() }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            Button(loc("Clear")) { model.clear() }
                .keyboardShortcut("k", modifiers: .command)
            Divider()
            Button(loc("Refine on-device")) { model.runRefinement() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model.mode != .arabizi)
        }
    }
}
