import Foundation
import HarfCore

/// Built-in sample text used for screenshots (`--render-assets`). Outputs are computed by the real engine.
enum SampleData {
    static func input(for mode: HarfMode) -> String {
        switch mode {
        case .arabizi:
            return "marhaba habibi, kifak?\nana ra7 aroo7 el beit ba3d shway\nbokra mnetla2a 3al 3asha, law sama7t"
        case .layout:
            return "hgsghl ugd;l ;dt hgphg?"
        case .pdfRepair:
            // "مرحبا بكم في المدرسة" / "سعر الكتاب 25 درهم" as presentation forms in visual order.
            return "\u{FE94}\u{FEB3}\u{FEAD}\u{FEAA}\u{FEE4}\u{FEDF}\u{FE8D} \u{FEF2}\u{FED3} \u{FEE2}\u{FEDC}\u{FE91} \u{FE8E}\u{FE92}\u{FEA3}\u{FEAE}\u{FEE3}\n"
                + "\u{FEE2}\u{FEEB}\u{FEAD}\u{FEA9} 25 \u{FE8F}\u{FE8E}\u{FE98}\u{FEDC}\u{FEDF}\u{FE8D} \u{FEAE}\u{FECC}\u{FEB3}"
        case .cleanup:
            return "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nالســـلام عليكم، الموعد الساعة ١٠:٣٠"
        }
    }

    static func history(engine: HarfEngine = HarfEngine()) -> [HistoryItem] {
        let now = Date()
        let items: [(HarfMode, String, TimeInterval)] = [
            (.arabizi, "shukran ktir", 120),
            (.layout, "hgsghl ugd;l", 14 * 60),
            (.pdfRepair, "\u{FEE2}\u{FEDC}\u{FEF4}\u{FEE0}\u{FECB} \u{FEE1}\u{FEFC}\u{FEB4}\u{FEDF}\u{FE8D}", 60 * 60),
            (.cleanup, "مُحَمَّدٌ رَسُولُ", 3 * 3600),
            (.arabizi, "yalla, law sama7t", 26 * 3600),
        ]
        return items.map { mode, input, ago in
            HistoryItem(date: now.addingTimeInterval(-ago), mode: mode, input: input,
                        output: engine.transform(input, mode: mode).output, origin: "sample")
        }
    }
}
