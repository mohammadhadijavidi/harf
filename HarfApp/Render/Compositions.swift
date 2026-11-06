import SwiftUI
import AppKit

/// README hero: the real window render on a dark backdrop with the name and tagline.
struct HeroComposition: View {
    static let size = CGSize(width: 1600, height: 1090)
    let window: NSImage   // includes an 80 pt shadow margin
    let lang: String

    var body: some View {
        let ar = lang == "ar"
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.07, green: 0.075, blue: 0.09), Color(red: 0.035, green: 0.04, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.89, green: 0.66, blue: 0.28).opacity(0.20), .clear],
                           center: UnitPoint(x: 0.5, y: 0.36), startRadius: 10, endRadius: 760)
            // Faint oversized letter as texture.
            Text(verbatim: "حرف")
                .font(.system(size: 620, weight: .black))
                .foregroundStyle(Color.white.opacity(0.018))
                .offset(y: 260)

            VStack(spacing: 14) {
                HStack(spacing: 18) {
                    BrandMark(size: 64)
                    Text(verbatim: ar ? "حرف" : "Harf")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                    if !ar {
                        Text(verbatim: "حرف")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(Color(red: 0.93, green: 0.72, blue: 0.36))
                    }
                }
                Text(verbatim: ar
                     ? "حوّل العربيزي، وصحّح لغة لوحة المفاتيح، وأصلح نصوص PDF العربية، في أي تطبيق على الماك."
                     : "Arabizi to Arabic, wrong-keyboard fixes and PDF Arabic repair, in every Mac app.")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }
            .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
            .padding(.top, 70)

            Image(nsImage: window)
                .resizable()
                .interpolation(.high)
                .frame(width: 1400 * 0.97, height: 960 * 0.97)
                .offset(y: 172)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }
}

/// The light-mode window on a soft paper backdrop.
struct LightComposition: View {
    static let size = CGSize(width: 1400, height: 960)
    let window: NSImage

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.93, green: 0.91, blue: 0.87), Color(red: 0.86, green: 0.84, blue: 0.80)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(nsImage: window).resizable().interpolation(.high).frame(width: 1400, height: 960)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// "How it works" diagram, drawn in SwiftUI with the app's theme.
struct HowItWorksDiagram: View {
    static let size = CGSize(width: 1600, height: 820)
    let loc: Localizer

    var body: some View {
        let t = Theme.dark
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("How Harf works")).font(.system(size: 40, weight: .bold)).foregroundStyle(t.text)
                Text(loc("Everything runs locally. No network, no account, no telemetry."))
                    .font(.system(size: 19)).foregroundStyle(t.secondary)
            }
            HStack(alignment: .center, spacing: 0) {
                column(title: loc("1. Text comes in"), width: 300) {
                    node("text.cursor", loc("Selection in any app"), loc("⌃⌥Space copies it with Accessibility"))
                    node("filemenu.and.selection", loc("Services menu"), loc("Right-click > Services > Harf"))
                    node("menubar.rectangle", loc("Menu bar"), loc("Transform the clipboard"))
                    node("macwindow", loc("Workbench window"), loc("Live preview and alternatives"))
                }
                arrow
                column(title: loc("2. Detect"), width: 300) {
                    node("magnifyingglass", loc("Mode detector"), loc("Explainable signals, not a black box"))
                    bullet(loc("Presentation forms U+FB50 to U+FEFC"))
                    bullet(loc("Letter positions and lexicon say reversed"))
                    bullet(loc("Wrong layout reads as real words"))
                    bullet(loc("Digit letters 2 3 5 6 7 8 9, dictionary hits"))
                }
                arrow
                column(title: loc("3. Transform"), width: 380) {
                    node("character.bubble", loc("Arabizi engine"), loc("Dictionary, rules, lexicon ranking, alternatives"))
                    node("keyboard", loc("Layout converter"), loc("Real macOS Arabic and Arabic - PC tables"))
                    node("doc.text.magnifyingglass", loc("PDF repair"), loc("Forms to letters, visual to logical order"))
                    node("wand.and.stars", loc("Cleanup"), loc("Tashkeel, tatweel, letters, digits"))
                    node("sparkles", loc("Optional on-device model"), loc("macOS 26 Apple Intelligence, with fallback"))
                }
                arrow
                column(title: loc("4. Back in place"), width: 260) {
                    node("arrow.uturn.backward", loc("Pasted over the selection"), loc("Clipboard restored afterwards"))
                    node("clock.arrow.circlepath", loc("Local history"), loc("Optional, stays on this Mac"))
                }
            }
        }
        .padding(64)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .leading)
        .background(
            ZStack {
                t.window
                RadialGradient(colors: [t.accent.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 900)
            }
        )
        .environment(\.loc, loc)
        .environment(\.layoutDirection, loc.layoutDirection)
    }

    private var arrow: some View {
        Image(systemName: "arrow.forward")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Theme.dark.accent)
            .frame(width: 56)
    }

    private func column<C: View>(title: String, width: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.dark.accent)
            content()
        }
        .frame(width: width, alignment: .leading)
    }

    private func node(_ symbol: String, _ title: String, _ detail: String) -> some View {
        let t = Theme.dark
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(t.accent)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(t.accentSoft))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.text)
                Text(detail).font(.system(size: 13)).foregroundStyle(t.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(t.hairline, lineWidth: 1))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.dark.accent.opacity(0.7)).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).font(.system(size: 13.5)).foregroundStyle(Theme.dark.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 6)
    }
}

/// The app icon, drawn in SwiftUI on Apple's 1024 pt macOS icon grid.
struct IconArtwork: View {
    /// (points, scale) for every macOS AppIcon slot.
    static let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
    static let defaultFont: String? = "Al Nile"

    var fontFamily: String? = IconArtwork.defaultFont

    var body: some View {
        let side: CGFloat = 824
        ZStack {
            // Shadow and body.
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .frame(width: side, height: side)
                .blur(radius: 18)
                .offset(y: 14)
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.23), Color(red: 0.05, green: 0.055, blue: 0.075)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: side, height: side)
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(RadialGradient(colors: [Color(red: 0.95, green: 0.70, blue: 0.30).opacity(0.22), .clear],
                                     center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 420))
                .frame(width: side, height: side)
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.03)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 3)
                .frame(width: side, height: side)

            // Calligrapher's measuring dots (nuqat) and baseline.
            VStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.72, blue: 0.36).opacity(0.55))
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(45))
                }
            }
            .offset(x: -215, y: 18)

            glyph
                .offset(x: 9, y: -144)
        }
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder private var glyph: some View {
        let font: Font = fontFamily.map { Font.custom($0, size: 600) } ?? .system(size: 560, weight: .bold)
        Text(verbatim: "ح")
            .font(font)
            .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.58), Color(red: 0.85, green: 0.57, blue: 0.18)],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
    }

}
