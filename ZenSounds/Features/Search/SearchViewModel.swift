import Foundation
import Combine

/// Search tab state. Books, passages, prayers and mysteries are matched synchronously on every
/// keystroke (small in-memory lists); verse text runs in `VerseSearchIndex` after a debounce, and a
/// new keystroke cancels the previous verse search.
@MainActor
final class SearchViewModel: ObservableObject {
    struct Results: Equatable {
        var books: [BibleBook] = []
        var passages: [PassageReference] = []
        var verses: [Verse] = []
        var prayers: [RosarySearch.PrayerHit] = []
        var mysteries: [RosarySearch.MysteryHit] = []

        var isEmpty: Bool {
            books.isEmpty && passages.isEmpty && verses.isEmpty && prayers.isEmpty && mysteries.isEmpty
        }
    }

    static let bookLimit = 8

    @Published var query = "" {
        didSet { if query != oldValue { update() } }
    }
    @Published private(set) var results = Results()
    @Published private(set) var isSearchingVerses = false
    /// Texts of exact passages ("jo 3:16"), loaded after the reference is recognized.
    @Published private(set) var passageTexts: [PassageReference: String] = [:]

    var language: BibleLanguage = .pt {
        didSet { if language != oldValue { update() } }
    }

    var isActive: Bool { !SearchText.fold(query).isEmpty }

    private var verseTask: Task<Void, Never>?
    private var passageTask: Task<Void, Never>?

    private func update() {
        verseTask?.cancel()
        passageTask?.cancel()
        let query = self.query
        guard !SearchText.fold(query).isEmpty else {
            results = Results()
            passageTexts = [:]
            isSearchingVerses = false
            return
        }

        let books = BibleCatalog.shared.books
        let repository = RosaryRepository.shared
        var next = Results()
        next.books = Array(BookMatcher.matches(query, in: books, language: language).prefix(Self.bookLimit))
        next.passages = ReferenceParser.parse(query, books: books, language: language)
        next.prayers = RosarySearch.prayers(query, in: repository.prayers, language: language)
        next.mysteries = RosarySearch.mysteries(query, in: repository.mysterySets)
        // Keep the previous verse hits until the new ones arrive, so the list doesn't flicker.
        next.verses = results.verses
        results = next

        loadPassageTexts(next.passages)
        // A recognized reference ("jo 3:16") isn't a text query.
        searchVerses(next.passages.isEmpty ? query : "")
    }

    private func loadPassageTexts(_ passages: [PassageReference]) {
        let language = self.language
        let wanted = passages.filter { $0.verse != nil }
        guard !wanted.isEmpty else { passageTexts = [:]; return }
        passageTask = Task {
            var texts: [PassageReference: String] = [:]
            for passage in wanted {
                guard let verse = passage.verse else { continue }
                if let found = await BibleRepository.shared.verseAsync(bookCode: passage.bookCode, chapter: passage.chapter, number: verse, language: language) {
                    texts[passage] = found.text
                }
            }
            guard !Task.isCancelled else { return }
            passageTexts = texts
        }
    }

    private func searchVerses(_ query: String) {
        guard SearchText.fold(query).count >= VerseSearchRules.minimumQueryLength else {
            results.verses = []
            isSearchingVerses = false
            return
        }
        let language = self.language
        let codes = BibleCatalog.shared.books.map(\.code)
        isSearchingVerses = true
        verseTask = Task {
            try? await Task.sleep(for: VerseSearchRules.debounce)
            guard !Task.isCancelled else { return }
            let hits = await VerseSearchIndex.shared.search(query, language: language, bookCodes: codes, limit: VerseSearchRules.resultLimit)
            guard !Task.isCancelled else { return }
            results.verses = hits.map { Verse(book: $0.bookCode, chapter: $0.chapter, number: $0.number, text: $0.text, language: language) }
            isSearchingVerses = false
        }
    }
}
