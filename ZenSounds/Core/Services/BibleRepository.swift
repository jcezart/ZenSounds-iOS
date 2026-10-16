import Foundation

/// Reads chapters from the bundled, pre-decompressed Bible JSON files
/// (`Resources/Bible/{BOOKCODE}_{lang}.json`, flattened at the bundle root).
/// Fully offline — no network access, matching the Android app's behavior.
nonisolated final class BibleRepository: @unchecked Sendable {
    static let shared = BibleRepository()

    private let cache = NSCache<NSString, NSArray>()
    /// Psalm superscriptions by chapter ("" when the chapter has none), filled by the same decode.
    private let subtitleCache = NSCache<NSString, NSString>()

    func chapter(bookCode: String, number: Int, language: BibleLanguage) -> [Verse] {
        let cacheKey = Self.cacheKey(bookCode: bookCode, number: number, language: language)
        if let cached = cache.object(forKey: cacheKey) as? [Verse] {
            return cached
        }
        return load(bookCode: bookCode, number: number, language: language)?.verses ?? []
    }

    /// The chapter's `hebrew_subtitle` (Psalms only), exactly as in the source text.
    func subtitle(bookCode: String, number: Int, language: BibleLanguage) -> String? {
        let cacheKey = Self.cacheKey(bookCode: bookCode, number: number, language: language)
        let cached = subtitleCache.object(forKey: cacheKey) as String?
            ?? load(bookCode: bookCode, number: number, language: language)?.subtitle
            ?? ""
        return cached.isEmpty ? nil : cached
    }

    func subtitleAsync(bookCode: String, number: Int, language: BibleLanguage) async -> String? {
        await Task.detached(priority: .userInitiated) { [self] in
            subtitle(bookCode: bookCode, number: number, language: language)
        }.value
    }

    private static func cacheKey(bookCode: String, number: Int, language: BibleLanguage) -> NSString {
        "\(language.rawValue):\(bookCode):\(number)" as NSString
    }

    private static func joined(_ pieces: [BibleContentPiece]) -> String {
        pieces.reduce(into: "") { partial, piece in
            switch piece {
            case .text(let value):
                partial += value
            case .lineBreak:
                partial += "\n"
            }
        }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load(bookCode: String, number: Int, language: BibleLanguage) -> (verses: [Verse], subtitle: String)? {
        guard let url = Bundle.main.url(forResource: "\(bookCode)_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(BibleRawFile.self, from: data),
              let wrapper = file.chapters[String(number)] else {
            return nil
        }

        var subtitle = ""
        var verses: [Verse] = []
        for item in wrapper.chapter.content {
            switch item {
            case .verse(let rawVerse):
                verses.append(Verse(book: bookCode, chapter: number, number: rawVerse.number,
                                    text: Self.joined(rawVerse.content), language: language))
            case .subtitle(let pieces):
                subtitle = Self.joined(pieces)
            case .other:
                break
            }
        }
        verses.sort { $0.number < $1.number }

        let cacheKey = Self.cacheKey(bookCode: bookCode, number: number, language: language)
        cache.setObject(verses as NSArray, forKey: cacheKey)
        subtitleCache.setObject(subtitle as NSString, forKey: cacheKey)
        return (verses, subtitle)
    }

    func verse(bookCode: String, chapter: Int, number: Int, language: BibleLanguage) -> Verse? {
        self.chapter(bookCode: bookCode, number: chapter, language: language).first { $0.number == number }
    }

    func chapterAsync(bookCode: String, number: Int, language: BibleLanguage) async -> [Verse] {
        await Task.detached(priority: .userInitiated) { [self] in
            chapter(bookCode: bookCode, number: number, language: language)
        }.value
    }

    func verseAsync(bookCode: String, chapter: Int, number: Int, language: BibleLanguage) async -> Verse? {
        await chapterAsync(bookCode: bookCode, number: chapter, language: language)
            .first { $0.number == number }
    }
}
