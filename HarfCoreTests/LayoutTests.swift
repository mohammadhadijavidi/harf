import XCTest
@testable import HarfCore

final class LayoutTests: XCTestCase {
    let c = KeyboardLayoutConverter()

    func testArabicPCGreeting() {
        XCTAssertEqual(c.toArabic("hgsghl ugd;l", layout: .pc), "السلام عليكم")
    }

    func testAppleArabicDiffersFromPC() {
        // The Apple layout puts ر on N and د on V; the PC layout puts ر on V and ى on N.
        XCTAssertEqual(c.toArabic("lvpfh", layout: .pc), "مرحبا")
        XCTAssertEqual(c.toArabic("lnpfh", layout: .apple), "مرحبا")
        XCTAssertNotEqual(c.toArabic("lvpfh", layout: .apple), "مرحبا")
    }

    func testAutomaticLayoutDetection() {
        let pc = c.convert("lvpfh")
        XCTAssertEqual(pc.direction, .toArabic)
        XCTAssertEqual(pc.layout, .pc)
        XCTAssertEqual(pc.output, "مرحبا")

        let apple = c.convert("lnpfh")
        XCTAssertEqual(apple.layout, .apple)
        XCTAssertEqual(apple.output, "مرحبا")
    }

    func testArabicToLatin() {
        let r = c.convert("اثممخ صخقمي")
        XCTAssertEqual(r.direction, .toLatin)
        XCTAssertEqual(r.output, "hello world")
    }

    func testLamAlefKeyMapsBackToB() {
        XCTAssertEqual(c.toLatin("لاشي", layout: .pc), "bad")
        XCTAssertEqual(c.toArabic("b", layout: .pc), "لا")
        XCTAssertEqual(c.toArabic("b", layout: .apple), "ز")
    }

    func testDigitsAreNotConvertedToArabicButArabicDigitsBecomeWestern() {
        XCTAssertEqual(c.toArabic("123", layout: .pc), "123")
        XCTAssertEqual(c.toLatin("١٢٣", layout: .pc), "123")
    }

    func testUnmappedCharactersArePreserved() {
        XCTAssertEqual(c.toArabic("hgsghl\n", layout: .pc), "السلام\n")
        XCTAssertEqual(c.toLatin("abc", layout: .pc), "abc")
    }

    func testEveryLetterRoundTrips() {
        for layout in KeyboardLayout.allCases {
            for ch in "abcdefghijklmnopqrstuvwxyz" {
                let arabic = c.toArabic(String(ch), layout: layout)
                XCTAssertNotEqual(arabic, String(ch), "\(ch) should map on \(layout)")
                XCTAssertEqual(c.toLatin(arabic, layout: layout), String(ch), "\(ch) on \(layout)")
            }
        }
    }

    func testTablesComeFromTheRealDump() {
        XCTAssertEqual(KeyboardLayout.pcEntries.first { $0.latin == "q" }?.arabic, "ض")
        XCTAssertEqual(KeyboardLayout.appleEntries.first { $0.latin == "z" }?.arabic, "ظ")
        XCTAssertEqual(KeyboardLayout.pcEntries.first { $0.latin == "z" }?.arabic, "ئ")
        XCTAssertEqual(KeyboardLayout.pc.inputSourceID, "com.apple.keylayout.ArabicPC")
    }

    func testForcedDirectionAndLayout() {
        let r = c.convert("lvpfh", direction: .toArabic, layout: .apple)
        XCTAssertEqual(r.layout, .apple)
        XCTAssertEqual(r.output, c.toArabic("lvpfh", layout: .apple))
    }

    func testScores() {
        XCTAssertGreaterThan(c.arabicScore("السلام عليكم"), 0.9)
        XCTAssertLessThan(c.arabicScore("ثممخ"), 0.5)
        XCTAssertGreaterThan(EnglishHeuristics.score("thank you for the help"), 0.9)
        XCTAssertLessThan(EnglishHeuristics.score("hgsghl ugd;l"), 0.3)
    }
}
