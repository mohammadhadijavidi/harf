import SwiftUI

/// A card surface with a hairline border and soft depth.
struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        let t = Theme.of(scheme)
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(t.card)
                    .shadow(color: .black.opacity(t.isDark ? 0.35 : 0.06), radius: t.isDark ? 18 : 14, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(t.hairline, lineWidth: 1))
    }
}

/// Small uppercase section label.
struct SectionLabel: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let key: String

    var body: some View {
        Text(loc.isRTL ? loc(key) : loc(key).uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(loc.isRTL ? 0 : 0.8)
            .foregroundStyle(Theme.of(scheme).tertiary)
    }
}

/// A keyboard shortcut drawn as key caps.
struct KeyCaps: View {
    @Environment(\.colorScheme) private var scheme
    let keys: [String]

    var body: some View {
        let t = Theme.of(scheme)
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                Text(k)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(t.secondary)
                    .frame(minWidth: 17, minHeight: 17)
                    .padding(.horizontal, 3)
                    .background(RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(t.cardRaised))
                    .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(t.hairline, lineWidth: 1))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: " "))
    }
}

/// Plain icon button with a hover highlight.
struct IconButton: View {
    @Environment(\.colorScheme) private var scheme
    let symbol: String
    let label: String
    var prominent = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let t = Theme.of(scheme)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(prominent ? t.accent : t.secondary)
                .frame(width: 28, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hover ? t.cardRaised : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Text button with an icon, used in headers.
struct PillButton: View {
    @Environment(\.colorScheme) private var scheme
    let symbol: String
    let title: String
    var filled = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let t = Theme.of(scheme)
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11.5, weight: .semibold))
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(filled ? t.accentText : t.text)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? AnyShapeStyle(t.accent.opacity(hover ? 0.9 : 1)) : AnyShapeStyle(hover ? t.cardRaised : t.card))
            )
            .overlay(Capsule(style: .continuous).strokeBorder(filled ? .clear : t.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(title)
    }
}

/// A custom segmented control (pure SwiftUI so it renders in screenshots too).
struct Segmented<Value: Hashable>: View {
    @Environment(\.colorScheme) private var scheme
    let items: [(Value, String)]
    @Binding var selection: Value
    var label: String = ""

    var body: some View {
        let t = Theme.of(scheme)
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let selected = item.0 == selection
                Button { selection = item.0 } label: {
                    Text(item.1)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? t.text : t.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected ? t.cardRaised : .clear)
                                .shadow(color: .black.opacity(selected ? (t.isDark ? 0.4 : 0.08) : 0), radius: 2, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.1)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.window.opacity(t.isDark ? 0.9 : 0.7)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(t.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// A toggle drawn as a chip with a check mark (pure SwiftUI).
struct ToggleChip: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        let t = Theme.of(scheme)
        Button { isOn.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? t.accent : t.tertiary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isOn ? t.text : t.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(isOn ? t.accentSoft : t.card))
            .overlay(Capsule(style: .continuous).strokeBorder(isOn ? t.accent.opacity(0.35) : t.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// A switch drawn in SwiftUI (used where a native Toggle would not render in screenshots).
struct MiniSwitch: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        let t = Theme.of(scheme)
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? t.accent : t.hairline.opacity(3))
                    .frame(width: 30, height: 18)
                Circle().fill(.white).frame(width: 14, height: 14).padding(2)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// The brand mark: the letter ح on a saffron tile.
struct BrandMark: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.19), Color(red: 0.05, green: 0.06, blue: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            Text(verbatim: "ح")
                .font(.custom("Al Nile", size: size * 0.62))
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.98, green: 0.82, blue: 0.52), Color(red: 0.84, green: 0.58, blue: 0.20)],
                                                startPoint: .top, endPoint: .bottom))
                .offset(x: size * 0.01, y: -size * 0.15)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// ScrollView in the app; plain clipped content while rendering screenshots (ImageRenderer cannot draw NSScrollView).
struct RenderSafeScroll<Content: View>: View {
    @Environment(\.isRenderingAssets) private var rendering
    @ViewBuilder var content: Content

    var body: some View {
        if rendering {
            content.frame(maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollView { content }
        }
    }
}
