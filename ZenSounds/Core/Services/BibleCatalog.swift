import Foundation

/// Loads the static Bible catalog (book list + curated daily-word references + translation
/// manifest) bundled with the app. All three files are produced offline from the Android
/// app's `assets/bible/manifest.json` and book JSONs — see MIGRATION_PROGRESS.md.
final class BibleCatalog {
    static let shared = BibleCatalog()

    let books: [BibleBook]
    let dailyReadings: [DailyReadingRef]
    let manifest: BibleManifest?

    private init() {
        books = Self.loadBooks()
        dailyReadings = Self.loadDailyReadings()
        manifest = Self.loadManifest()
    }

    func book(code: String) -> BibleBook? {
        books.first { $0.code == code }
    }

    private static func loadBooks() -> [BibleBook] {
        guard let url = Bundle.main.url(forResource: "books", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([BibleBook].self, from: data) else {
            assertionFailure("books.json ausente ou inválido no bundle")
            return []
        }
        return decoded.sorted { $0.order < $1.order }
    }

    private static func loadDailyReadings() -> [DailyReadingRef] {
        guard let url = Bundle.main.url(forResource: "daily_readings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DailyReadingRef].self, from: data) else {
            assertionFailure("daily_readings.json ausente ou inválido no bundle")
            return []
        }
        return decoded
    }

    private static func loadManifest() -> BibleManifest? {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(BibleManifest.self, from: data)
    }
}
