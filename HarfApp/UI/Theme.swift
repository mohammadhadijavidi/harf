import SwiftUI

/// Design tokens. Warm "ink and paper" palette with a saffron accent, tuned separately for light and dark.
struct Theme {
    let window: Color
    let sidebar: Color
    let card: Color
    let cardRaised: Color
    let hairline: Color
    let text: Color
    let secondary: Color
    let tertiary: Color
    let accent: Color
    let accentSoft: Color
    let accentText: Color
    let success: Color
    let warning: Color
    let isDark: Bool

    static let dark = Theme(
        window: Color(red: 0.059, green: 0.067, blue: 0.082),
        sidebar: Color(red: 0.078, green: 0.086, blue: 0.106),
        card: Color(red: 0.094, green: 0.106, blue: 0.129),
        cardRaised: Color(red: 0.122, green: 0.137, blue: 0.165),
        hairline: Color.white.opacity(0.075),
        text: Color(red: 0.925, green: 0.929, blue: 0.937),
        secondary: Color(red: 0.62, green: 0.64, blue: 0.68),
        tertiary: Color(red: 0.43, green: 0.45, blue: 0.49),
        accent: Color(red: 0.886, green: 0.663, blue: 0.282),
        accentSoft: Color(red: 0.886, green: 0.663, blue: 0.282).opacity(0.14),
        accentText: Color(red: 0.11, green: 0.08, blue: 0.03),
        success: Color(red: 0.42, green: 0.78, blue: 0.56),
        warning: Color(red: 0.93, green: 0.70, blue: 0.32),
        isDark: true)

    static let light = Theme(
        window: Color(red: 0.965, green: 0.957, blue: 0.937),
        sidebar: Color(red: 0.937, green: 0.925, blue: 0.898),
        card: Color.white,
        cardRaised: Color(red: 0.985, green: 0.98, blue: 0.97),
        hairline: Color.black.opacity(0.085),
        text: Color(red: 0.10, green: 0.11, blue: 0.125),
        secondary: Color(red: 0.37, green: 0.39, blue: 0.42),
        tertiary: Color(red: 0.55, green: 0.565, blue: 0.595),
        accent: Color(red: 0.70, green: 0.46, blue: 0.10),
        accentSoft: Color(red: 0.70, green: 0.46, blue: 0.10).opacity(0.11),
        accentText: Color.white,
        success: Color(red: 0.18, green: 0.56, blue: 0.34),
        warning: Color(red: 0.72, green: 0.48, blue: 0.08),
        isDark: false)

    static func of(_ scheme: ColorScheme) -> Theme { scheme == .dark ? .dark : .light }
}

private struct RenderingKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True while the app renders its own screenshots (`--render-assets`). AppKit-backed controls are
    /// swapped for pure SwiftUI equivalents because ImageRenderer cannot draw them.
    var isRenderingAssets: Bool {
        get { self[RenderingKey.self] }
        set { self[RenderingKey.self] = newValue }
    }
}

enum HarfFont {
    static func arabic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static let mono = Font.system(size: 11.5, weight: .medium, design: .monospaced)
}
