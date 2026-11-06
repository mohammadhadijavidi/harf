import SwiftUI
import HarfCore

/// The main window: tools on the side, live input and output in the middle.
struct WorkbenchView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isRenderingAssets) private var rendering
    let model: AppModel
    var axTrusted: Bool = false

    var body: some View {
        let t = Theme.of(scheme)
        let loc = model.localizer
        HStack(spacing: 0) {
            SidebarView(model: model, topInset: rendering ? 52 : 46, axTrusted: axTrusted)
                .frame(width: 262)
                .background(sidebarBackground(t))
            Rectangle().fill(t.hairline).frame(width: 1)
            MainPane(model: model)
        }
        .background(t.window)
        .environment(\.loc, loc)
        .environment(\.layoutDirection, loc.layoutDirection)
        .environment(\.locale, loc.locale)
    }

    @ViewBuilder private func sidebarBackground(_ t: Theme) -> some View {
        if rendering {
            t.sidebar
        } else {
            ZStack {
                t.sidebar.opacity(0.55)
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}

struct MainPane: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isRenderingAssets) private var rendering
    let model: AppModel

    var body: some View {
        let t = Theme.of(scheme)
        VStack(alignment: .leading, spacing: 16) {
            header(t)
            OptionsBar(model: model)
            if let s = model.suggestion {
                SuggestionBanner(detection: s) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { model.setMode(s.mode) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(alignment: .top, spacing: 14) {
                InputCard(model: model)
                OutputCard(model: model)
            }
            .frame(maxHeight: .infinity)
            if model.mode == .arabizi, let a = model.result.arabizi, !a.ambiguousSegments.isEmpty {
                AlternativesCard(result: a) { idx, id in model.chooseAlternative(idx, forSegment: id) }
            }
            StatusBar(notes: model.result.notes)
        }
        .padding(.horizontal, 26)
        .padding(.top, rendering ? 26 : 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ t: Theme) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc(model.mode.titleKey))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(t.text)
                Text(loc(model.mode.headlineKey))
                    .font(.system(size: 13))
                    .foregroundStyle(t.secondary)
            }
            .id(model.mode)
            .transition(.opacity)
            Spacer()
            PillButton(symbol: "doc.on.clipboard", title: loc("Paste")) { model.pasteInput() }
            PillButton(symbol: "arrow.uturn.backward", title: loc("Use result as input")) { model.useOutputAsInput() }
            PillButton(symbol: "doc.on.doc", title: loc("Copy result"), filled: true) { model.copyOutput() }
        }
    }
}

// MARK: - Options

struct OptionsBar: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.mode {
            case .arabizi: arabiziOptions
            case .layout: layoutOptions
            case .pdfRepair: pdfOptions
            case .cleanup: cleanupOptions
            }
            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    private func binding<T>(_ path: WritableKeyPath<HarfOptions, T>) -> Binding<T> {
        Binding(get: { model.options[keyPath: path] }, set: { model.options[keyPath: path] = $0 })
    }

    @ViewBuilder private var arabiziOptions: some View {
        let t = Theme.of(scheme)
        HStack(spacing: 6) {
            Image(systemName: "text.book.closed").foregroundStyle(t.tertiary)
            Text(loc("Dictionary, rules and lexicon. Click an underlined word's alternatives below."))
                .foregroundStyle(t.secondary)
        }
        .font(.system(size: 12))
        Spacer(minLength: 8)
        RefineButton(model: model)
    }

    @ViewBuilder private var layoutOptions: some View {
        Segmented(items: [(Optional<ConversionDirection>.none, loc("Auto direction")),
                          (.some(.toArabic), loc("To Arabic")),
                          (.some(.toLatin), loc("To English"))],
                  selection: binding(\.layoutDirection), label: loc("Direction"))
        Segmented(items: [(Optional<KeyboardLayout>.none, loc("Auto layout")),
                          (.some(.apple), loc("Arabic")),
                          (.some(.pc), loc("Arabic - PC"))],
                  selection: binding(\.keyboardLayout), label: loc("Keyboard layout"))
    }

    @ViewBuilder private var pdfOptions: some View {
        Segmented(items: [(PDFTextRepair.ReversalMode.automatic, loc("Detect reversed text")),
                          (.always, loc("Always reverse")),
                          (.never, loc("Never reverse"))],
                  selection: binding(\.pdf.reversal), label: loc("Reversed text"))
        ToggleChip(title: loc("Remove tatweel"), isOn: binding(\.pdf.removeTatweel))
        ToggleChip(title: loc("Remove invisible marks"), isOn: binding(\.pdf.removeInvisibles))
    }

    @ViewBuilder private var cleanupOptions: some View {
        ToggleChip(title: loc("Tashkeel"), isOn: binding(\.cleanup.removeTashkeel))
        ToggleChip(title: loc("Tatweel"), isOn: binding(\.cleanup.removeTatweel))
        ToggleChip(title: loc("Alef forms"), isOn: binding(\.cleanup.normalizeAlef))
        ToggleChip(title: loc("ى to ي"), isOn: binding(\.cleanup.normalizeAlefMaqsura))
        ToggleChip(title: loc("ة to ه"), isOn: binding(\.cleanup.normalizeTaMarbuta))
        Segmented(items: [(DigitStyle.keep, loc("Digits as is")), (.western, "123"), (.arabicIndic, "١٢٣"), (.persian, "۱۲۳")],
                  selection: binding(\.cleanup.digits), label: loc("Digits"))
    }
}

struct RefineButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let model: AppModel

    var body: some View {
        let t = Theme.of(scheme)
        let available = OnDeviceRefiner.availability == .available
        Button { model.runRefinement() } label: {
            HStack(spacing: 6) {
                if model.refine == .running {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "sparkles").font(.system(size: 11.5, weight: .semibold))
                }
                Text(loc("Refine on-device")).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(available ? t.accent : t.tertiary)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(available ? t.accentSoft : t.card))
            .overlay(Capsule(style: .continuous).strokeBorder(available ? t.accent.opacity(0.3) : t.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!available || model.input.isEmpty)
        .help(available ? loc("Polish spelling with Apple's on-device model. Nothing leaves your Mac.")
                        : loc("Needs macOS 26 with Apple Intelligence turned on. The rule-based result is used."))
        .accessibilityLabel(loc("Refine on-device"))
    }
}

// MARK: - Panes

struct InputCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    @Environment(\.isRenderingAssets) private var rendering
    let model: AppModel

    var body: some View {
        let t = Theme.of(scheme)
        let rtl = ArabicScript.isPredominantlyRTL(model.input)
        Card {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(titleKey: "Input", rtlText: rtl, count: model.input.count) {
                    if !model.input.isEmpty {
                        IconButton(symbol: "xmark.circle", label: loc("Clear")) { model.clear() }
                    }
                }
                Rectangle().fill(t.hairline).frame(height: 1)
                ZStack(alignment: .topLeading) {
                    if model.input.isEmpty {
                        Text(loc(model.mode.placeholderKey))
                            .font(.system(size: 16))
                            .foregroundStyle(t.tertiary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    if rendering {
                        Text(verbatim: model.input)
                            .font(.system(size: rtl ? 21 : 17))
                            .lineSpacing(rtl ? 6 : 4)
                            .foregroundStyle(t.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                    } else {
                        TextEditor(text: Binding(get: { model.input }, set: { model.setInput($0) }))
                            .font(.system(size: rtl ? 21 : 17))
                            .lineSpacing(rtl ? 6 : 4)
                            .foregroundStyle(t.text)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .accessibilityLabel(loc("Input"))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            model.setInput(first)
            return true
        }
    }
}

struct OutputCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let model: AppModel

    var body: some View {
        let t = Theme.of(scheme)
        let output = model.displayedOutput
        let rtl = ArabicScript.isPredominantlyRTL(output)
        Card {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(titleKey: "Result", rtlText: rtl, count: output.count) {
                    if case .refined = model.refine {
                        Label(loc("Refined on-device"), systemImage: "sparkles")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(t.accent)
                    }
                    if !output.isEmpty {
                        IconButton(symbol: "doc.on.doc", label: loc("Copy result"), prominent: true) { model.copyOutput() }
                    }
                }
                Rectangle().fill(t.hairline).frame(height: 1)
                RenderSafeScroll {
                    Group {
                        if output.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: model.mode.symbol)
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(t.tertiary.opacity(0.8))
                                Text(loc("The result appears here as you type."))
                                    .font(.system(size: 13))
                                    .foregroundStyle(t.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 70)
                        } else {
                            Text(styledOutput(output, t))
                                .font(.system(size: rtl ? 23 : 17, weight: .regular))
                                .lineSpacing(rtl ? 8 : 4)
                                .foregroundStyle(t.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                                .accessibilityLabel(loc("Result"))
                                .accessibilityValue(output)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(t.accent.opacity(t.isDark ? 0.05 : 0.04))
                .blur(radius: 20)
        )
    }

    /// Underlines Arabizi words that have alternatives (dotted) and rule-only guesses (dashed, dimmer).
    private func styledOutput(_ output: String, _ t: Theme) -> AttributedString {
        guard model.mode == .arabizi, case .idle = model.refine, let a = model.result.arabizi else {
            return AttributedString(output)
        }
        var s = AttributedString()
        for seg in a.segments {
            var piece = AttributedString(seg.output)
            if seg.isAmbiguous {
                piece.swiftUI.underlineStyle = Text.LineStyle(pattern: .dot, color: t.accent)
            }
            if seg.origin == .rules {
                piece.swiftUI.foregroundColor = t.text.opacity(0.78)
            }
            s.append(piece)
        }
        return s
    }
}

struct PaneHeader<Trailing: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let titleKey: String
    let rtlText: Bool
    let count: Int
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let t = Theme.of(scheme)
        HStack(spacing: 8) {
            SectionLabel(key: titleKey)
            if count > 0 {
                Text(verbatim: rtlText ? loc("Arabic · RTL") : loc("Latin · LTR"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(t.secondary)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Capsule().fill(t.cardRaised))
                    .overlay(Capsule().strokeBorder(t.hairline, lineWidth: 1))
                Text(verbatim: loc.format("Characters: %d", count))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(t.tertiary)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
    }
}

// MARK: - Alternatives, suggestion, status

struct AlternativesCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let result: ArabiziResult
    let choose: (Int, Int) -> Void

    var body: some View {
        let t = Theme.of(scheme)
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(key: "Alternatives")
                    Spacer()
                    Text(loc("Pick the spelling you meant"))
                        .font(.system(size: 11))
                        .foregroundStyle(t.tertiary)
                }
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(result.ambiguousSegments.prefix(12)) { seg in
                        HStack(spacing: 5) {
                            Text(verbatim: seg.source)
                                .font(HarfFont.mono)
                                .foregroundStyle(t.tertiary)
                                .environment(\.layoutDirection, .leftToRight)
                            Image(systemName: "arrow.forward")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(t.tertiary.opacity(0.7))
                            ForEach(Array(seg.candidates.prefix(4).enumerated()), id: \.offset) { idx, cand in
                                let selected = idx == seg.selection
                                Button { choose(idx, seg.id) } label: {
                                    Text(verbatim: cand)
                                        .font(.system(size: 15, weight: selected ? .semibold : .regular))
                                        .foregroundStyle(selected ? t.accentText : t.text)
                                        .padding(.horizontal, 9)
                                        .frame(height: 26)
                                        .background(Capsule(style: .continuous).fill(selected ? t.accent : t.cardRaised))
                                        .overlay(Capsule(style: .continuous).strokeBorder(selected ? .clear : t.hairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(cand)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.window.opacity(t.isDark ? 0.6 : 0.5)))
                    }
                }
            }
            .padding(14)
        }
    }
}

struct SuggestionBanner: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let detection: ModeDetection
    let apply: () -> Void

    var body: some View {
        let t = Theme.of(scheme)
        HStack(spacing: 10) {
            Image(systemName: "lightbulb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(t.accent)
            Text(loc(detection.reason.key))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(t.text)
            Spacer()
            Button(action: apply) {
                Text(loc.format("Switch to %@", loc(detection.mode.titleKey)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(t.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.accentSoft))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(t.accent.opacity(0.25), lineWidth: 1))
    }
}

struct StatusBar: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.loc) private var loc
    let notes: [HarfNote]

    var body: some View {
        let t = Theme.of(scheme)
        HStack(spacing: 14) {
            ForEach(notes, id: \.self) { note in
                Label {
                    Text(note.text(loc))
                } icon: {
                    Image(systemName: note.symbol)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(t.secondary)
            }
            Spacer()
            Label {
                Text(loc("On this Mac only"))
            } icon: {
                Image(systemName: "lock.shield")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(t.tertiary)
        }
        .frame(height: 18)
    }
}

/// Wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { x = 0; y += lineHeight + lineSpacing; lineHeight = 0 }
            x += s.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, s.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += lineHeight + lineSpacing; lineHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}
