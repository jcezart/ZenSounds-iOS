import Foundation

/// Offline full-text verse search. The first query in a language loads every book once in the
/// background (about 31k verses) and keeps the folded text in memory; later queries are a linear
/// scan that stops at the result limit and honors task cancellation (new keystrokes cancel it).
actor VerseSearchIndex {
    static let shared = VerseSearchIndex()

    struct Hit: Hashable, Sendable {
        let bookCode: String
        let chapter: Int
        let number: Int
        let text: String
    }

    private struct Entry: Sendable {
        let hit: Hit
        let folded: String
    }

    private var entries: [BibleLanguage: [Entry]] = [:]

    /// `bookCodes` in canonical order, so results follow the Bible's order.
    func search(_ query: String, language: BibleLanguage, bookCodes: [String], limit: Int) async -> [Hit] {
        let key = SearchText.words(query)
        guard key.count >= VerseSearchRules.minimumQueryLength else { return [] }
        let index = await entries(for: language, bookCodes: bookCodes)
        var hits: [Hit] = []
        for (offset, entry) in index.enumerated() {
            if offset % 2_000 == 0, Task.isCancelled { return [] }
            if entry.folded.contains(key) {
                hits.append(entry.hit)
                if hits.count >= limit { break }
            }
        }
        return hits
    }

    private func entries(for language: BibleLanguage, bookCodes: [String]) async -> [Entry] {
        if let cached = entries[language] { return cached }
        var built: [Entry] = []
        built.reserveCapacity(32_000)
        for code in bookCodes {
            for verse in BibleRepository.shared.bookVerses(bookCode: code, language: language) {
                let hit = Hit(bookCode: code, chapter: verse.chapter, number: verse.number, text: verse.text)
                built.append(Entry(hit: hit, folded: SearchText.words(verse.text)))
            }
        }
        entries[language] = built
        return built
    }
}
