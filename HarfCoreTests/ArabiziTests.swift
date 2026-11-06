import XCTest
@testable import HarfCore

final class ArabiziTests: XCTestCase {
    let t = ArabiziTransliterator()

    private func ar(_ s: String) -> String { t.transliterate(s).text }

    // MARK: Dictionary and phrases

    func testHeadlineExample() {
        XCTAssertEqual(ar("ana ra7 aroo7 el beit"), "أنا رح أروح البيت")
    }

    func testCommonGreetings() {
        XCTAssertEqual(ar("marhaba"), "مرحبا")
        XCTAssertEqual(ar("shukran"), "شكرا")
        XCTAssertEqual(ar("7abibi"), "حبيبي")
        XCTAssertEqual(ar("habibi"), "حبيبي")
        XCTAssertEqual(ar("kifak"), "كيفك")
        XCTAssertEqual(ar("yalla"), "يلا")
    }

    func testCaseAndDiacriticsAreIgnoredForLookup() {
        XCTAssertEqual(ar("Marhaba"), "مرحبا")
        XCTAssertEqual(ar("SHUKRAN"), "شكرا")
    }

    func testMultiWordPhraseWins() {
        let r = t.transliterate("shu esmak")
        XCTAssertEqual(r.text, "شو اسمك")
        XCTAssertEqual(r.segments.filter(\.isWord).count, 1, "the phrase is one segment")
        XCTAssertEqual(r.segments.first?.origin, .dictionary)
    }

    func testDictionaryEntriesAcrossDataFiles() {
        XCTAssertEqual(ar("kitab"), "كتاب")
        XCTAssertEqual(ar("shams"), "شمس")
        XCTAssertEqual(ar("saba7"), "صباح")
        XCTAssertEqual(ar("so2al"), "سؤال")
        XCTAssertEqual(ar("madrase"), "مدرسة")
        XCTAssertEqual(ar("sayyara"), "سيارة")
    }

    // MARK: Article

    func testSeparateArticleJoinsNextWord() {
        let r = t.transliterate("el kalb")
        XCTAssertEqual(r.text, "الكلب")
        XCTAssertEqual(r.segments.filter(\.isWord).count, 1)
    }

    func testHyphenatedArticleAndSunLetters() {
        XCTAssertEqual(ar("al-kitab"), "الكتاب")
        XCTAssertEqual(ar("ash-shams"), "الشمس")
        XCTAssertEqual(ar("as-saba7"), "الصباح")
    }

    func testAttachedArticleOnDictionaryWord() {
        XCTAssertEqual(ar("ilkitab"), "الكتاب")
        XCTAssertEqual(ar("elsayyara"), "السيارة")
    }

    // MARK: Particles and suffixes

    func testConjunctionPrefix() {
        XCTAssertEqual(ar("wana"), "وأنا")
    }

    func testPronounSuffixes() {
        XCTAssertEqual(ar("beitna"), "بيتنا")
        XCTAssertEqual(ar("beito"), "بيته")
        XCTAssertEqual(ar("sayyaratna"), "سيارتنا", "ta marbuta becomes ta before a suffix")
    }

    func testAttachSuffixHelper() {
        XCTAssertEqual(ArabiziTransliterator.attachSuffix("ك", to: "مدرسة"), "مدرستك")
        XCTAssertEqual(ArabiziTransliterator.attachSuffix("نا", to: "بيت"), "بيتنا")
    }

    // MARK: Punctuation and passthrough

    func testArabicPunctuation() {
        XCTAssertEqual(ar("kifak?"), "كيفك؟")
        XCTAssertEqual(ar("marhaba, habibi"), "مرحبا، حبيبي")
        XCTAssertEqual(ar("yalla; marhaba"), "يلا؛ مرحبا")
    }

    func testURLsMentionsNumbersAndAcronymsPassThrough() {
        XCTAssertEqual(ar("https://example.com"), "https://example.com")
        XCTAssertEqual(ar("@harf"), "@harf")
        XCTAssertEqual(ar("#yalla"), "#yalla")
        XCTAssertEqual(ar("name@example.com"), "name@example.com")
        XCTAssertEqual(ar("2026"), "2026")
        XCTAssertEqual(ar("PDF"), "PDF")
        XCTAssertEqual(ar("marhaba PDF 2026"), "مرحبا PDF 2026")
    }

    func testWhitespaceAndNewlinesArePreserved() {
        XCTAssertEqual(ar("marhaba\nshukran"), "مرحبا\nشكرا")
        XCTAssertEqual(ar("  yalla  "), "  يلا  ")
    }

    func testPhrasesDoNotCrossLines() {
        XCTAssertEqual(ar("shu\nesmak"), ar("shu") + "\n" + ar("esmak"))
    }

    // MARK: Alternatives

    func testAmbiguousWordOffersAlternatives() {
        let r = t.transliterate("ra7")
        XCTAssertEqual(r.text, "رح")
        let seg = try! XCTUnwrap(r.ambiguousSegments.first)
        XCTAssertTrue(seg.candidates.contains("راح"))
    }

    func testSelectingAnAlternativeChangesTheText() {
        let r = t.transliterate("ana ra7")
        let seg = try! XCTUnwrap(r.ambiguousSegments.first { $0.source == "ra7" })
        let idx = try! XCTUnwrap(seg.candidates.firstIndex(of: "راح"))
        XCTAssertEqual(r.selecting(idx, forSegment: seg.id).text, "أنا راح")
        XCTAssertEqual(r.selecting(99, forSegment: seg.id).segments[seg.id].selection, seg.candidates.count - 1)
    }

    func testConfidenceReflectsDictionaryCoverage() {
        XCTAssertEqual(t.transliterate("marhaba habibi").confidence, 1, accuracy: 0.001)
        XCTAssertEqual(t.transliterate("").confidence, 0)
        XCTAssertLessThan(t.transliterate("qzxbrt").confidence, 1)
    }

    func testTokenizerKeepsDigitApostrophes() {
        let tokens = ArabiziTransliterator.tokenize("3'ali 9'arb")
        XCTAssertEqual(tokens, [.word("3'ali"), .space(" "), .word("9'arb")])
    }

    func testTokenizerSplitsPunctuation() {
        let tokens = ArabiziTransliterator.tokenize("kifak?!")
        XCTAssertEqual(tokens, [.word("kifak"), .other("?"), .other("!")])
    }

    func testRealDataLoaded() {
        let data = LanguageData.shared
        XCTAssertGreaterThan(data.arabizi.count, 1000)
        XCTAssertGreaterThan(data.lexiconWords.count, 1000)
        XCTAssertGreaterThanOrEqual(data.maxPhraseWords, 2)
    }
}

/// Rule engine tests run against an empty lexicon so every result is the pure rule reading.
final class RuleEngineTests: XCTestCase {
    let empty = LanguageData(arabiziSources: [], lexiconSources: [])

    private func rule(_ word: String) -> String {
        RuleTransliterator(data: empty).candidates(for: word).first?.text ?? ""
    }

    func testDigitLetters() {
        XCTAssertEqual(rule("b7r"), "بحر")
        XCTAssertEqual(rule("3'rb"), "غرب")
        XCTAssertEqual(rule("9'rb"), "ضرب")
        XCTAssertEqual(rule("6'lm"), "ظلم")
        XCTAssertEqual(rule("5br"), "خبر")
        XCTAssertEqual(rule("7'br"), "خبر")
        XCTAssertEqual(rule("8lb"), "قلب")
        XCTAssertEqual(rule("9br"), "صبر")
        XCTAssertEqual(rule("3lm"), "علم")
        XCTAssertEqual(rule("6ab5"), "طبخ")
    }

    func testDigraphs() {
        XCTAssertEqual(rule("shms"), "شمس")
        XCTAssertEqual(rule("khbz"), "خبز")
        XCTAssertEqual(rule("ghrb"), "غرب")
        XCTAssertEqual(rule("thlj"), "ثلج")
        XCTAssertEqual(rule("dhhb"), "ذهب")
        XCTAssertEqual(rule("chms"), "شمس")
    }

    func testVowelRules() {
        XCTAssertEqual(rule("kitab"), "كتاب", "long vowel in the last syllable")
        XCTAssertEqual(rule("kbir"), "كبير")
        XCTAssertEqual(rule("kalb"), "كلب", "short vowel before two consonants")
        XCTAssertEqual(rule("salam"), "سلام")
        XCTAssertEqual(rule("maktab"), "مكتب")
        XCTAssertEqual(rule("kbira"), "كبيرة", "final a after three consonants is ta marbuta")
        XCTAssertEqual(rule("sayyara"), "سيارة", "doubled consonant written once")
        XCTAssertEqual(rule("madrasa"), "مدرسة")
        XCTAssertEqual(rule("madraseh"), "مدرسة", "final eh is ta marbuta")
        XCTAssertEqual(rule("kteer"), "كتير")
        XCTAssertEqual(rule("noor"), "نور")
    }

    func testInitialVowelsAndHamza() {
        XCTAssertEqual(rule("akl"), "أكل")
        XCTAssertEqual(rule("2akl"), "أكل")
        XCTAssertEqual(rule("2ism"), "إسم")
        XCTAssertEqual(rule("so2al"), "سؤال")
        XCTAssertEqual(rule("mas2ala"), "مسألة")
    }

    func testUppercaseMarksEmphatics() {
        XCTAssertEqual(rule("maTar"), "مطار")
        XCTAssertEqual(rule("mTr"), "مطر")
        XCTAssertEqual(rule("mtr"), "متر")
    }

    func testCandidatesIncludeEmphaticAlternatives() {
        let all = RuleTransliterator(data: empty).candidates(for: "sabr", limit: 12).map(\.text)
        XCTAssertEqual(all.first, "سبر")
        XCTAssertTrue(all.contains("صبر"))
    }

    func testLexiconRanksCandidates() {
        let data = LanguageData(arabiziSources: [], lexiconSources: ["حبيب\nصباح\nضيف"])
        let rules = RuleTransliterator(data: data)
        XCTAssertEqual(rules.candidates(for: "habib").first?.text, "حبيب")
        XCTAssertEqual(rules.candidates(for: "habib").first?.inLexicon, true)
        XCTAssertEqual(rules.candidates(for: "saba7").first?.text, "صباح")
        XCTAssertEqual(rules.candidates(for: "deif").first?.text, "ضيف")
    }

    func testLexiconSpellingIsUsedForOutput() {
        let data = LanguageData(arabiziSources: [], lexiconSources: ["أكل"])
        let r = ArabiziTransliterator(data: data).transliterate("akl")
        XCTAssertEqual(r.text, "أكل")
        XCTAssertEqual(r.segments.first?.origin, .lexicon)
    }

    func testRuleOnlyWordsAreMarkedAsGuesses() {
        let r = ArabiziTransliterator(data: empty).transliterate("b7r")
        XCTAssertEqual(r.segments.first?.origin, .rules)
    }
}

final class LanguageDataTests: XCTestCase {
    func testParsesFormatCommentsAndMerges() {
        let src = """
        # comment
        ana, ena | أنا, انا | C

        Marhabā | مرحبا | C
        ana | انا, آنا | L
        shu esmak, shu ismak | شو اسمك | L
        """
        let d = LanguageData(arabiziSources: [src], lexiconSources: ["# c\nأنا\nمرحبا\nأنا"])
        XCTAssertEqual(d.arabizi["ana"]?.candidates, ["أنا", "انا", "آنا"])
        XCTAssertEqual(d.arabizi["ena"]?.dialects, ["C"])
        XCTAssertEqual(d.arabizi["marhaba"]?.candidates, ["مرحبا"], "Latin diacritics are folded")
        XCTAssertEqual(d.maxPhraseWords, 2)
        XCTAssertEqual(d.lexiconWords.count, 3)
        XCTAssertEqual(d.lexiconEntry("انا")?.word, "أنا", "lookup ignores hamza on alef")
        XCTAssertEqual(d.lexiconEntry("مرحبا")?.rank, 1)
    }

    func testFold() {
        XCTAssertEqual(LanguageData.fold("  Shu   Esmak "), "shu esmak")
        XCTAssertEqual(LanguageData.fold("3\u{2019}ali"), "3'ali")
    }
}
