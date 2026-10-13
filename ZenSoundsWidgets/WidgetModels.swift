import Foundation

/// Small, widget-extension-local copies of just what the widget needs: the 132 curated daily
/// readings (with pre-resolved pt/en text, ~40KB) and the 66-book catalog (~8KB). Deliberately
/// NOT the full offline Bible (14MB+ decompressed) — the widget process has a tight memory
/// budget, and it never needs to render arbitrary chapters, only today's word.
struct DailyReadingText: Codable {
    let book: String
    let chapter: Int
    let verse: Int
    let text_pt: String
    let text_en: String
}

struct WidgetBibleBook: Codable {
    let code: String
    let order: Int
    let chapters: Int
    let name_pt: String
    let name_en: String
}

enum WidgetLanguage: String {
    case pt
    case en

    static var systemDefault: WidgetLanguage {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") == true ? .pt : .en
    }

    static var preferred: WidgetLanguage {
        let defaults = UserDefaults(suiteName: WidgetDailyWordStore.appGroupID)
        guard let rawValue = defaults?.string(forKey: "zensounds.bible_language"), rawValue != "system" else {
            return systemDefault
        }
        return Self(rawValue: rawValue) ?? systemDefault
    }
}

final class WidgetDataSource {
    static let shared = WidgetDataSource()

    let readings: [DailyReadingText]
    let books: [WidgetBibleBook]

    private init() {
        readings = Self.load("daily_readings_resolved", [DailyReadingText].self) ?? []
        books = Self.load("books", [WidgetBibleBook].self) ?? []
    }

    func book(code: String) -> WidgetBibleBook? {
        books.first { $0.code == code }
    }

    func text(for reading: DailyReadingText, language: WidgetLanguage) -> String {
        language == .pt ? reading.text_pt : reading.text_en
    }

    private static func load<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
