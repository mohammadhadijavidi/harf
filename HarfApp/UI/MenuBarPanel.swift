import SwiftUI
import HarfCore

/// The menu bar extra: shortcut reminder, clipboard actions and the last result.
struct MenuBarPanel: View {
    @Environment(\.colorScheme) private var scheme
    let model: AppModel
    var axTrusted: Bool
    var runClipboard: (QuickAction) -> Void = { _ in }
    var openWorkbench: () -> Void = {}
    var openSettings: () -> Void = {}
    var quit: () -> Void = {}

    var body: some View {
        let t = Theme.of(scheme)
        let loc = model.localizer
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: loc.isRTL ? "حرف" : "Harf").font(.system(size: 14, weight: .bold)).foregroundStyle(t.text)
                    Text(loc("Arabic text toolkit")).font(.system(size: 10.5)).foregroundStyle(t.tertiary)
                }
                Spacer()
                IconButton(symbol: "gearshape", label: loc("Settings"), action: openSettings)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text(loc("Smart fix on selection"))
                    } icon: {
                        Image(systemName: "wand.and.rays")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(t.text)
                    Spacer()
                    KeyCaps(keys: QuickAction.smart.keyCaps)
                }
                HStack(spacing: 6) {
                    Circle().fill(axTrusted ? t.success : t.warning).frame(width: 6, height: 6)
                    Text(axTrusted ? loc("Ready in every app") : loc("Needs Accessibility access"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(t.tertiary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(t.accentSoft))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(t.accent.opacity(0.22), lineWidth: 1))
            .padding(.horizontal, 12)

            SectionLabel(key: "Transform clipboard")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
            VStack(spacing: 2) {
                ForEach([QuickAction.arabizi, .layout, .pdfRepair, .cleanup]) { action in
                    MenuRow(action: action) { runClipboard(action) }
                }
            }
            .padding(.horizontal, 6)

            if let last = model.history.first {
                SectionLabel(key: "Last result")
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)
                let rtl = ArabicScript.isPredominantlyRTL(last.output)
                Text(verbatim: last.output)
                    .font(.system(size: rtl ? 17 : 14))
                    .foregroundStyle(t.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(t.card))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(t.hairline, lineWidth: 1))
                    .padding(.horizontal, 12)
            }

            Rectangle().fill(t.hairline).frame(height: 1).padding(.top, 12)
            HStack {
                Button(action: openWorkbench) {
                    Label(loc("Open Workbench"), systemImage: "macwindow")
                }
                Spacer()
                Button(action: quit) {
                    Text(loc("Quit"))
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(t.secondary)
            .padding(.horizontal, 16)
            .frame(height: 38)
        }
        .frame(width: 320)
        .background(t.window)
        .environment(\.loc, loc)
        .environment(\.layoutDirection, loc.layoutDirection)
    }
}

private struct MenuRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let action: QuickAction
    let run: () -> Void
    @State private var hover = false

    private var mode: HarfMode {
        switch action {
        case .arabizi, .smart: return .arabizi
        case .layout: return .layout
        case .pdfRepair: return .pdfRepair
        case .cleanup: return .cleanup
        }
    }

    var body: some View {
        let t = Theme.of(scheme)
        Button(action: run) {
            HStack(spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(t.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(loc(mode.titleKey)).font(.system(size: 12.5, weight: .medium)).foregroundStyle(t.text)
                    Text(loc(mode.subtitleKey)).font(.system(size: 10.5)).foregroundStyle(t.tertiary).lineLimit(1)
                }
                Spacer()
                KeyCaps(keys: action.keyCaps)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hover ? t.card : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(loc(mode.titleKey))
    }
}
