import Foundation
import Testing
@testable import ZenSounds

@MainActor
struct ReadingTests {
    private var books: [BibleBook] { BibleCatalog.shared.books }

    @Test func testamentsSplitThe66Books() {
        let old = BibleTestament.old.books(from: books)
        let new = BibleTestament.new.books(from: books)
        #expect(old.count == 39)
        #expect(new.count == 27)
        #expect(old.first?.code == "GEN")
        #expect(old.last?.code == "MAL")
        #expect(new.first?.code == "MAT")
        #expect(new.last?.code == "REV")
    }

    @Test func chapterNavigationCrossesBookEdges() {
        let gen1 = ChapterLocation(bookCode: "GEN", chapter: 1)
        #expect(ChapterNavigation.previous(of: gen1, in: books) == nil)
        #expect(ChapterNavigation.next(of: gen1, in: books) == ChapterLocation(bookCode: "GEN", chapter: 2))
        #expect(ChapterNavigation.next(of: ChapterLocation(bookCode: "GEN", chapter: 50), in: books)
                == ChapterLocation(bookCode: "EXO", chapter: 1))
        #expect(ChapterNavigation.previous(of: ChapterLocation(bookCode: "EXO", chapter: 1), in: books)
                == ChapterLocation(bookCode: "GEN", chapter: 50))
        #expect(ChapterNavigation.next(of: ChapterLocation(bookCode: "REV", chapter: 22), in: books) == nil)
        #expect(ChapterNavigation.next(of: ChapterLocation(bookCode: "XXX", chapter: 1), in: books) == nil)
    }

    @Test func fontScaleSnapsToStepsAndStopsAtTheEnds() {
        #expect(ReadingFontScale.clamped(1.0) == 1.0)
        #expect(ReadingFontScale.clamped(9) == 1.5)
        #expect(ReadingFontScale.clamped(-3) == 0.85)
        #expect(ReadingFontScale.clamped(.nan) == ReadingFontScale.defaultValue)
        #expect(ReadingFontScale.larger(than: 1.0) == 1.15)
        #expect(ReadingFontScale.smaller(than: 1.0) == 0.85)
        #expect(ReadingFontScale.larger(than: 1.5) == nil)
        #expect(ReadingFontScale.smaller(than: 0.85) == nil)
    }

    @Test func psalmSuperscriptionComesFromTheSourceText() {
        #expect(BibleRepository.shared.subtitle(bookCode: "PSA", number: 23, language: .pt) == "Salmo de Davi:")
        #expect(BibleRepository.shared.subtitle(bookCode: "PSA", number: 23, language: .en) != nil)
        #expect(BibleRepository.shared.subtitle(bookCode: "GEN", number: 1, language: .pt) == nil)
        // Reading the subtitle must not change the chapter's verses.
        #expect(BibleRepository.shared.chapter(bookCode: "PSA", number: 23, language: .pt).first?.number == 1)
    }

    @Test func chapterShareTextNumbersEveryVerse() {
        let verses = [
            Verse(book: "PSA", chapter: 23, number: 1, text: "A", language: .pt),
            Verse(book: "PSA", chapter: 23, number: 2, text: "B", language: .pt)
        ]
        #expect(ChapterShareText.make(title: "Salmos 23", verses: verses) == "Salmos 23\n\n1 A\n2 B\n\n— Orante")
    }
}

@MainActor
struct BibleHeroTests {
    @Test func heroQuoteDropsTheAcrosticLetterOnly() {
        #expect(BibleBooksView.heroText("Nun :Tua palavra é lâmpada") == "Tua palavra é lâmpada")
        #expect(BibleBooksView.heroText("Thy word is a lamp unto my feet") == "Thy word is a lamp unto my feet")
    }
}
