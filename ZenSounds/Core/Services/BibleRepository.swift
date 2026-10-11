import Foundation

/// Reads chapters from the bundled, pre-decompressed Bible JSON files
/// (`Resources/Bible/{BOOKCODE}_{lang}.json`, flattened at the bundle root).
/// Fully offline — no network access, matching the Android app's behavior.
final class BibleRepository {
    static let shared = BibleRepository()

    private let cache = NSCache<NSString, NSArray>()

    func chapter(bookCode: String, number: Int, language: BibleLanguage) -> [Verse] {
        let cacheKey = "\(language.rawValue):\(bookCode):\(number)" as NSString
        if let cached = cache.object(forKey: cacheKey) as? [Verse] {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "\(bookCode)_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(BibleRawFile.self, from: data),
              let wrapper = file.chapters[String(number)] else {
            return []
        }

        let verses: [Verse] = wrapper.chapter.content.compactMap { item -> Verse? in
            guard case .verse(let rawVerse) = item else { return nil }
            let text = rawVerse.content.reduce(into: "") { partial, piece in
                switch piece {
                case .text(let value):
                    partial += value
                case .lineBreak:
                    partial += "\n"
                }
            }.trimmingCharacters(in: .whitespacesAndNewlines)
            return Verse(book: bookCode, chapter: number, number: rawVerse.number, text: text, language: language)
        }.sorted { $0.number < $1.number }

        cache.setObject(verses as NSArray, forKey: cacheKey)
        return verses
    }

    func verse(bookCode: String, chapter: Int, number: Int, language: BibleLanguage) -> Verse? {
        self.chapter(bookCode: bookCode, number: chapter, language: language).first { $0.number == number }
    }
}
