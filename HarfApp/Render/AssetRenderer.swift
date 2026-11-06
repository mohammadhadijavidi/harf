import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import HarfCore

/// Renders README images from the real app views (`--render-assets <dir>`).
///
/// Every screen is the same SwiftUI view type the app shows, filled with built-in sample data.
/// AppKit-backed controls (TextEditor, ScrollView) are swapped for SwiftUI equivalents via
/// `isRenderingAssets` because ImageRenderer cannot draw them.
@MainActor
enum AssetRenderer {
    static let windowSize = CGSize(width: 1240, height: 800)

    static func renderAll(to dir: URL) -> Bool {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var ok = true
        func save(_ view: some View, _ name: String, size: CGSize, scale: CGFloat = 2) {
            if !write(view, size: size, scale: scale, to: dir.appendingPathComponent(name)) { ok = false }
        }

        // Workbench, every mode, both languages and both appearances.
        for lang in ["en", "ar"] {
            for scheme in [ColorScheme.dark, .light] {
                let suffix = "\(lang)-\(scheme == .dark ? "dark" : "light")"
                for mode in HarfMode.allCases {
                    save(window(mode: mode, lang: lang, scheme: scheme), "workbench-\(mode.rawValue)-\(suffix).png",
                         size: windowSize + 120)
                }
                save(menuBar(lang: lang, scheme: scheme), "menubar-\(suffix).png", size: CGSize(width: 320 + 120, height: 600))
            }
        }

        // Hero and framed light screenshot.
        for lang in ["en", "ar"] {
            let shot = image(of: WindowFrame(rtl: lang == "ar") { workbench(mode: .arabizi, lang: lang) }
                .padding(80).environment(\.colorScheme, .dark), size: windowSize + 160)
            save(HeroComposition(window: shot, lang: lang).environment(\.colorScheme, .dark),
                 lang == "en" ? "hero.png" : "hero-ar.png", size: HeroComposition.size)
            let light = image(of: WindowFrame(rtl: lang == "ar") { workbench(mode: .arabizi, lang: lang) }
                .padding(80).environment(\.colorScheme, .light), size: windowSize + 160)
            save(LightComposition(window: light).environment(\.colorScheme, .light),
                 lang == "en" ? "screenshot-light.png" : "screenshot-light-ar.png", size: LightComposition.size)
            save(HowItWorksDiagram(loc: Localizer(code: lang)).environment(\.colorScheme, .dark),
                 lang == "en" ? "how-it-works.png" : "how-it-works-ar.png", size: HowItWorksDiagram.size)
        }

        // App icon at every macOS size, plus font candidates for review.
        let iconDir = dir.appendingPathComponent("AppIcon.appiconset")
        try? FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)
        for (points, scale) in IconArtwork.sizes {
            let px = points * scale
            save(IconArtwork(), "AppIcon.appiconset/icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png",
                 size: CGSize(width: 1024, height: 1024), scale: CGFloat(px) / 1024)
        }
        save(IconArtwork(), "icon.png", size: CGSize(width: 1024, height: 1024), scale: 0.5)
        let candidates = IconArtwork.candidateFonts()
        try? candidates.map { "\($0.family)\t\($0.available)" }.joined(separator: "\n")
            .write(to: dir.appendingPathComponent("icon-fonts.txt"), atomically: true, encoding: .utf8)
        for c in candidates where c.available {
            save(IconArtwork(fontFamily: c.family), "icon-candidates/\(c.family.replacingOccurrences(of: " ", with: "_")).png",
                 size: CGSize(width: 1024, height: 1024), scale: 0.5)
        }
        return ok
    }

    // MARK: Scenes

    static func sampleModel(mode: HarfMode, lang: String) -> AppModel {
        let defaults = UserDefaults(suiteName: "harf.render.\(lang)") ?? .standard
        let m = AppModel(defaults: defaults, persist: false)
        m.language = lang == "ar" ? .arabic : .english
        m.setMode(mode)
        m.setInput(SampleData.input(for: mode))
        if mode == .cleanup { var o = m.options; o.cleanup.digits = .western; m.options = o }
        m.seedHistory(SampleData.history())
        return m
    }

    static func workbench(mode: HarfMode, lang: String) -> some View {
        WorkbenchView(model: sampleModel(mode: mode, lang: lang), axTrusted: true)
            .environment(\.isRenderingAssets, true)
            .frame(width: windowSize.width, height: windowSize.height)
    }

    static func window(mode: HarfMode, lang: String, scheme: ColorScheme) -> some View {
        WindowFrame(rtl: lang == "ar") { workbench(mode: mode, lang: lang) }
            .padding(60)
            .environment(\.colorScheme, scheme)
    }

    static func menuBar(lang: String, scheme: ColorScheme) -> some View {
        let model = sampleModel(mode: .arabizi, lang: lang)
        return MenuBarPanel(model: model, axTrusted: true)
            .environment(\.isRenderingAssets, true)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
            .padding(60)
            .frame(width: 440, height: 600, alignment: .top)
            .environment(\.colorScheme, scheme)
    }

    // MARK: Rendering

    static func image(of view: some View, size: CGSize, scale: CGFloat = 2) -> NSImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        guard let cg = renderer.cgImage else { return NSImage(size: size) }
        return NSImage(cgImage: cg, size: size)
    }

    @discardableResult
    static func write(_ view: some View, size: CGSize, scale: CGFloat, to url: URL) -> Bool {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        guard let cg = renderer.cgImage else {
            FileHandle.standardError.write(Data("render failed: \(url.lastPathComponent)\n".utf8))
            return false
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, cg, nil)
        return CGImageDestinationFinalize(dest)
    }
}

private func + (lhs: CGSize, rhs: CGFloat) -> CGSize { CGSize(width: lhs.width + rhs, height: lhs.height + rhs) }

/// A macOS window: rounded corners, hairline border, traffic lights and a deep shadow.
struct WindowFrame<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let rtl: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let dark = scheme == .dark
        content
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                }
                .frame(width: 12 * 3 + 16, height: 12)
                .padding(.leading, 20)
                .padding(.top, 20)
            }
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(dark ? Color.white.opacity(0.14) : Color.black.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(dark ? 0.55 : 0.18), radius: 40, y: 22)
    }
}
