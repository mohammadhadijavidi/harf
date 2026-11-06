import XCTest
@testable import HarfCore

final class PDFRepairTests: XCTestCase {
    let r = PDFTextRepair()

    // "السلام عليكم" as presentation forms, logical order (lam-alef is one ligature glyph).
    let greetingForms = "\u{FE8D}\u{FEDF}\u{FEB4}\u{FEFC}\u{FEE1} \u{FECB}\u{FEE0}\u{FEF4}\u{FEDC}\u{FEE2}"
    // The same glyphs in visual order, as many PDF extractors return them.
    let greetingVisualForms = "\u{FEE2}\u{FEDC}\u{FEF4}\u{FEE0}\u{FECB} \u{FEE1}\u{FEFC}\u{FEB4}\u{FEDF}\u{FE8D}"
    // "مرحبا بكم في المدرسة" in visual order with presentation forms.
    let welcomeVisualForms = "\u{FE94}\u{FEB3}\u{FEAD}\u{FEAA}\u{FEE4}\u{FEDF}\u{FE8D} \u{FEF2}\u{FED3} \u{FEE2}\u{FEDC}\u{FE91} \u{FE8E}\u{FE92}\u{FEA3}\u{FEAE}\u{FEE3}"

    func testPresentationFormsToBaseLetters() {
        let (text, report) = r.repair(greetingForms)
        XCTAssertEqual(text, "السلام عليكم")
        XCTAssertEqual(report.ligaturesSplit, 1)
        XCTAssertEqual(report.presentationFormsMapped, 9)
        XCTAssertEqual(report.reversedLines, 0)
    }

    func testVisualOrderPresentationFormsAreDetectedAndFixed() {
        let evidence = r.reversalEvidence(greetingVisualForms)
        XCTAssertTrue(evidence.isReversed, "\(evidence)")
        let (text, report) = r.repair(greetingVisualForms)
        // The lam-alef ligature is reversed as one glyph; splitting it first would yield "ال" instead of "لا".
        XCTAssertEqual(text, "السلام عليكم")
        XCTAssertEqual(report.reversedLines, 1)
    }

    func testSentenceInVisualOrderWithForms() {
        XCTAssertEqual(r.repair(welcomeVisualForms).text, "مرحبا بكم في المدرسة")
    }

    func testVisualOrderBaseLettersAreDetectedByLetterPositionsAndLexicon() {
        let visual = String("مرحبا بكم في المدرسة".reversed())
        XCTAssertEqual(visual, "ةسردملا يف مكب ابحرم")
        XCTAssertTrue(r.reversalEvidence(visual).isReversed)
        XCTAssertEqual(r.repair(visual).text, "مرحبا بكم في المدرسة")
    }

    func testLogicalTextIsLeftAlone() {
        let text = "مرحبا بكم في المدرسة"
        XCTAssertFalse(r.reversalEvidence(text).isReversed)
        let (out, report) = r.repair(text)
        XCTAssertEqual(out, text)
        XCTAssertFalse(report.changedAnything)
    }

    func testNumbersAndLatinKeepTheirOrderWhenReversing() {
        let logical = "سعر الكتاب 25 درهم في PDF Expert"
        let visual = PDFTextRepair.visualToLogical(logical)
        XCTAssertTrue(visual.contains("25"))
        XCTAssertTrue(visual.contains("PDF Expert"))
        XCTAssertEqual(PDFTextRepair.visualToLogical(visual), logical)
        XCTAssertEqual(r.repair(visual).text, logical)
    }

    func testDecimalsAndTimesStayTogether() {
        let logical = "الساعة 10:30 والسعر 3.5"
        XCTAssertEqual(PDFTextRepair.visualToLogical(PDFTextRepair.visualToLogical(logical)), logical)
        XCTAssertTrue(PDFTextRepair.visualToLogical(logical).contains("10:30"))
        XCTAssertTrue(PDFTextRepair.visualToLogical(logical).contains("3.5"))
    }

    func testBracketsAreMirrored() {
        XCTAssertEqual(PDFTextRepair.visualToLogical("(ابحرم)"), "(مرحبا)")
        XCTAssertEqual(PDFTextRepair.visualToLogical("«ابحرم»"), "«مرحبا»")
    }

    func testTatweelAndInvisiblesAreRemoved() {
        let (text, report) = r.repair("مـــرحبا\u{200B} بكم\u{FEFF}")
        XCTAssertEqual(text, "مرحبا بكم")
        XCTAssertEqual(report.tatweelRemoved, 3)
        XCTAssertEqual(report.invisiblesRemoved, 2)
    }

    func testOptionsCanKeepTatweelAndSkipReversal() {
        var o = PDFTextRepair.Options()
        o.removeTatweel = false
        o.reversal = .never
        XCTAssertEqual(r.repair("ابحرمـ", options: o).text, "ابحرمـ")
        o.reversal = .always
        XCTAssertEqual(r.repair("ابحرم", options: o).text, "مرحبا")
    }

    func testMultipleLinesAreRepairedIndependently() {
        let visual = String("مرحبا بكم".reversed()) + "\n" + "Page 3" + "\n" + String("في المدرسة".reversed())
        XCTAssertEqual(r.repair(visual).text, "مرحبا بكم\nPage 3\nفي المدرسة")
    }

    func testShapeClassification() {
        XCTAssertEqual(PDFTextRepair.shape("\u{FE91}"), .initial)   // beh initial
        XCTAssertEqual(PDFTextRepair.shape("\u{FE92}"), .medial)
        XCTAssertEqual(PDFTextRepair.shape("\u{FE90}"), .final)
        XCTAssertEqual(PDFTextRepair.shape("\u{FE8F}"), .isolated)
        XCTAssertEqual(PDFTextRepair.shape("\u{0628}"), .none)
    }

    func testAllahLigatureAndFormsA() {
        XCTAssertEqual(r.repair("\u{FDF2}").text, "الله")
        XCTAssertEqual(r.repair("\u{FB58}").text, "\u{067E}") // peh initial form (Persian)
    }
}
