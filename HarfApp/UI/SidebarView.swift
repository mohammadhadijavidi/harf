import SwiftUI
import HarfCore

struct SidebarView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: AppModel
    var topInset: CGFloat = 46
    var axTrusted: Bool

    var body: some View {
        let t = Theme.of(scheme)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: loc.isRTL ? "حرف" : "Harf")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(t.text)
                    Text(loc("Arabic text toolkit"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(t.tertiary)
                }
            }
            .padding(.top, topInset)
            .padding(.horizontal, 18)
            .padding(.bottom, 22)

            SectionLabel(key: "Tools").padding(.horizontal, 20).padding(.bottom, 8)
            VStack(spacing: 3) {
                ForEach(HarfMode.allCases) { mode in
                    ModeRow(mode: mode, selected: model.mode == mode) {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { model.setMode(mode) }
                    }
                }
            }
            .padding(.horizontal, 10)

            SectionLabel(key: "History").padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 8)
            if model.history.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(t.tertiary)
                    Text(loc("Your conversions appear here. History stays on this Mac."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(t.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
            } else {
                RenderSafeScroll {
                    VStack(spacing: 2) {
                        ForEach(model.history.prefix(30)) { item in
                            HistoryRow(item: item) { model.restore(item) }
                                .contextMenu {
                                    Button(loc("Delete")) { model.deleteHistory(item) }
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }

            Spacer(minLength: 12)

            ShortcutCard(axTrusted: axTrusted)
                .padding(12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct ModeRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let mode: HarfMode
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let t = Theme.of(scheme)
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(selected ? t.accent : t.secondary)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? t.accentSoft : t.cardRaised.opacity(t.isDark ? 0.6 : 1)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(loc(mode.titleKey))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.text)
                    Text(loc(mode.subtitleKey))
                        .font(.system(size: 11))
                        .foregroundStyle(t.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if hover || selected {
                    Text(verbatim: "⌘\(mode.shortcutDigit)")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(t.tertiary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? t.card : (hover ? t.card.opacity(0.55) : .clear))
                    .shadow(color: .black.opacity(selected ? (t.isDark ? 0.3 : 0.05) : 0), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? t.hairline : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(loc(mode.titleKey))
        .accessibilityHint(loc(mode.subtitleKey))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct HistoryRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let item: HistoryItem
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let t = Theme.of(scheme)
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: item.mode.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(t.tertiary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: firstLine(item.output))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(t.text)
                        .lineLimit(1)
                    Text(verbatim: firstLine(item.input))
                        .font(.system(size: 10.5))
                        .foregroundStyle(t.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Text(verbatim: Self.relative(item.date, loc))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(t.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hover ? t.card.opacity(0.7) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(firstLine(item.output))
    }

    private func firstLine(_ s: String) -> String {
        s.split(whereSeparator: \.isNewline).first.map(String.init) ?? s
    }

    static func relative(_ date: Date, _ loc: Localizer) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: loc.isRTL ? "ar@numbers=latn" : "en")
        return f.localizedString(for: date, relativeTo: Date())
    }
}

private struct ShortcutCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let axTrusted: Bool

    var body: some View {
        let t = Theme.of(scheme)
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(loc("Fix any selection"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(t.text)
                Spacer()
                KeyCaps(keys: ["⌃", "⌥", "Space"])
            }
            Text(loc("Select text in any app and press the shortcut. Harf detects the problem and fixes it in place."))
                .font(.system(size: 11))
                .foregroundStyle(t.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Circle().fill(axTrusted ? t.success : t.warning).frame(width: 7, height: 7)
                Text(axTrusted ? loc("Accessibility access granted") : loc("Needs Accessibility access"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(t.tertiary)
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(t.card.opacity(t.isDark ? 0.8 : 1)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(t.hairline, lineWidth: 1))
    }
}
