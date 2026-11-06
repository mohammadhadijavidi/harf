import XCTest
@testable import HarfCore

final class CleanupTests: XCTestCase {
    let c = TextCleanup()

    func testRemovesTashkeel() {
        XCTAssertEqual(c.clean("مُحَمَّدٌ").text, "محمد")
        XCTAssertEqual(c.clean("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ").text, "بسم الله الرحمن الرحيم")
        XCTAssertEqual(c.removeTashkeel("كَتَبَ الوَلَدُ الدَّرْسَ"), "كتب الولد الدرس")
    }

    func testReportCountsMarks() {
        let (_, report) = c.clean("مُحَمَّدٌ")
        XCTAssertEqual(report.marksRemoved, 5)
        XCTAssertTrue(report.changedAnything)
    }

    func testRemovesTatweel() {
        XCTAssertEqual(c.clean("الســـلام").text, "السلام")
    }

    func testNormalizationIsOptInAndSelective() {
        XCTAssertEqual(c.clean("أحمد إلى آخر").text, "أحمد إلى آخر", "off by default")
        var o = TextCleanup.Options()
        o.normalizeAlef = true
        XCTAssertEqual(c.clean("أحمد إلى آخر", options: o).text, "احمد الى اخر")
        o.normalizeAlefMaqsura = true
        XCTAssertEqual(c.clean("إلى", options: o).text, "الي")
        o = TextCleanup.Options()
        o.normalizeTaMarbuta = true
        XCTAssertEqual(c.clean("مدرسة", options: o).text, "مدرسه")
        o = TextCleanup.Options()
        o.normalizeHamza = true
        XCTAssertEqual(c.clean("سؤال رئيس", options: o).text, "سوال رييس")
    }

    func testPersianLettersCanBeUnified() {
        var o = TextCleanup.Options()
        o.unifyPersianLetters = true
        XCTAssertEqual(c.clean("کتاب ی", options: o).text, "كتاب ي")
    }

    func testSearchNormalizationPreset() {
        XCTAssertEqual(c.clean("أَهْلاً بِالمَدْرَسَةِ", options: .searchNormalization).text, "اهلا بالمدرسه")
    }

    func testDigitConversion() {
        XCTAssertEqual(c.convertDigits("2026", to: .arabicIndic), "٢٠٢٦")
        XCTAssertEqual(c.convertDigits("2026", to: .persian), "۲۰۲۶")
        XCTAssertEqual(c.convertDigits("٢٠٢٦ و ۱۴۰۵", to: .western), "2026 و 1405")
        XCTAssertEqual(c.convertDigits("سنة 2026", to: .keep), "سنة 2026")
        XCTAssertEqual(c.convertDigits("٣.١٤", to: .western), "3.14")
    }

    func testDigitReportOnlyCountsChanges() {
        var o = TextCleanup.Options()
        o.digits = .western
        XCTAssertEqual(c.clean("12 ٣٤", options: o).report.digitsConverted, 2)
    }

    func testWhitespaceTidying() {
        XCTAssertEqual(c.clean("مرحبا    بكم  \nسطر").text, "مرحبا بكم\nسطر")
        var o = TextCleanup.Options()
        o.tidyWhitespace = false
        XCTAssertEqual(c.clean("a  b ", options: o).text, "a  b ")
    }

    func testLatinTextIsUntouched() {
        XCTAssertEqual(c.clean("Hello, world").text, "Hello, world")
    }
}

final class ScriptTests: XCTestCase {
    func testCounts() {
        let counts = ArabicScript.counts("مرحبا hello")
        XCTAssertEqual(counts.arabic, 5)
        XCTAssertEqual(counts.latin, 5)
        XCTAssertEqual(counts.arabicRatio, 0.5, accuracy: 0.001)
        XCTAssertEqual(ArabicScript.counts("\u{FEDF}\u{FEE0}").presentationForms, 2)
    }

    func testDirection() {
        XCTAssertTrue(ArabicScript.isPredominantlyRTL("مرحبا بكم in Dubai"))
        XCTAssertFalse(ArabicScript.isPredominantlyRTL("Welcome to دبي"))
        XCTAssertFalse(ArabicScript.isPredominantlyRTL("123"))
    }

    func testLookupKey() {
        XCTAssertEqual(ArabicScript.lookupKey("أَنا"), "انا")
        XCTAssertEqual(ArabicScript.lookupKey("إلى"), "الي")
        XCTAssertEqual(ArabicScript.lookupKey("مدرسة"), "مدرسه")
    }

    func testCharacterClasses() {
        XCTAssertTrue(ArabicScript.isTashkeel("\u{064E}"))
        XCTAssertTrue(ArabicScript.isTashkeel("\u{0670}"))
        XCTAssertFalse(ArabicScript.isTashkeel("\u{0628}"))
        XCTAssertTrue(ArabicScript.isPresentationForm("\u{FEFB}"))
        XCTAssertFalse(ArabicScript.isPresentationForm("\u{FEFF}"))
        XCTAssertTrue(ArabicScript.isArabicLetter("\u{06A9}"))
    }
}

final class DetectorTests: XCTestCase {
    let engine = HarfEngine()

    private func detect(_ s: String) -> ModeDetection { ModeDetector(engine: engine).detect(s) }

    func testDetectsArabizi() {
        let d = detect("ana ra7 aroo7 el beit")
        XCTAssertEqual(d.mode, .arabizi)
        XCTAssertEqual(d.reason, .arabiziPattern)
    }

    func testDetectsLatinTypedOnWrongLayout() {
        let d = detect("hgsghl ugd;l")
        XCTAssertEqual(d.mode, .layout)
        XCTAssertEqual(d.layoutDirection, .toArabic)
    }

    func testDetectsArabicTypedOnWrongLayout() {
        let d = detect("اثممخ صخقمي")
        XCTAssertEqual(d.mode, .layout)
        XCTAssertEqual(d.layoutDirection, .toLatin)
    }

    func testDetectsPresentationForms() {
        XCTAssertEqual(detect("\u{FE8D}\u{FEDF}\u{FEB4}\u{FEFC}\u{FEE1}").reason, .presentationForms)
    }

    func testDetectsReversedArabic() {
        let d = detect("ةسردملا يف مكب ابحرم")
        XCTAssertEqual(d.mode, .pdfRepair)
        XCTAssertEqual(d.reason, .reversedOrder)
    }

    func testRegularArabicGoesToCleanup() {
        XCTAssertEqual(detect("مرحبا بكم في المدرسة").mode, .cleanup)
    }

    func testPlainEnglishIsLeftAlone() {
        let d = detect("I will send the file tomorrow")
        XCTAssertFalse(d.shouldTransform)
    }

    func testSmartTransform() {
        let (d, r) = engine.smartTransform("hgsghl ugd;l")
        XCTAssertEqual(d.mode, .layout)
        XCTAssertEqual(r.output, "السلام عليكم")
    }
}

final class EngineTests: XCTestCase {
    let engine = HarfEngine()

    func testArabiziModeNotes() {
        let r = engine.transform("ana ra7 aroo7 el beit", mode: .arabizi)
        XCTAssertEqual(r.output, "أنا رح أروح البيت")
        XCTAssertNotNil(r.arabizi)
        XCTAssertTrue(r.notes.contains(.arabiziConfidence(percent: 100)))
    }

    func testLayoutModeHonoursForcedOptions() {
        var o = HarfOptions()
        o.layoutDirection = .toArabic
        o.keyboardLayout = .pc
        let r = engine.transform("lvpfh", mode: .layout, options: o)
        XCTAssertEqual(r.output, "مرحبا")
        XCTAssertEqual(r.notes, [.layoutDetected(direction: .toArabic, layout: .pc)])
    }

    func testPDFModeNotes() {
        let r = engine.transform("\u{FEE2}\u{FEDC}\u{FEF4}\u{FEE0}\u{FECB}", mode: .pdfRepair)
        XCTAssertEqual(r.output, "عليكم")
        XCTAssertTrue(r.notes.contains(.reversedOrderFixed(lines: 1)))
        XCTAssertTrue(r.notes.contains(.presentationFormsMapped(5)))
    }

    func testCleanupModeNotes() {
        var o = HarfOptions()
        o.cleanup.digits = .arabicIndic
        let r = engine.transform("سَنة 2026", mode: .cleanup, options: o)
        XCTAssertEqual(r.output, "سنة ٢٠٢٦")
        XCTAssertEqual(r.notes, [.marksRemoved(1), .digitsConverted(4)])
    }

    func testNothingToChange() {
        XCTAssertEqual(engine.transform("مرحبا", mode: .cleanup).notes, [.nothingToChange])
    }
}

final class RefinerTests: XCTestCase {
    func testAcceptsPlausibleRefinement() {
        XCTAssertEqual(OnDeviceRefiner.validate("«أنا رايح عالبيت»", draft: "انا رايح ع البيت"), .refined("أنا رايح عالبيت"))
    }

    func testRejectsNonArabicOrRunawayAnswers() {
        XCTAssertEqual(OnDeviceRefiner.validate("I am going home", draft: "أنا رايح البيت"), .keptDraft(reason: "not-arabic"))
        XCTAssertEqual(OnDeviceRefiner.validate(String(repeating: "كلام ", count: 40), draft: "أنا رايح"), .keptDraft(reason: "length"))
        XCTAssertEqual(OnDeviceRefiner.validate("أنا\nرايح\nالبيت", draft: "أنا رايح البيت"), .keptDraft(reason: "lines"))
        XCTAssertEqual(OnDeviceRefiner.validate("  ", draft: "أنا"), .keptDraft(reason: "empty"))
        XCTAssertEqual(OnDeviceRefiner.validate("أنا", draft: "أنا"), .keptDraft(reason: "unchanged"))
    }
}
