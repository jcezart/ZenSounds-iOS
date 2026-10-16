import Foundation
import Combine
import WidgetKit

enum BibleLanguage: String, Codable, CaseIterable, Identifiable {
    case pt
    case en

    var id: String { rawValue }

    static let storageKey = "zensounds.bible_language"
    static let sharedDefaults = UserDefaults(suiteName: "group.com.juliocezar.zensounds") ?? .standard

    static var systemDefault: BibleLanguage {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") == true ? .pt : .en
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case pt
    case en

    var id: String { rawValue }

    static let storageKey = BibleLanguage.storageKey
    static let sharedDefaults = BibleLanguage.sharedDefaults

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .pt:
            return Locale(identifier: "pt-BR")
        case .en:
            return Locale(identifier: "en")
        }
    }

    var bibleLanguage: BibleLanguage {
        switch self {
        case .system:
            return BibleLanguage.systemDefault
        case .pt:
            return .pt
        case .en:
            return .en
        }
    }

    static func selection(from rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .system
    }

    static var current: AppLanguage {
        selection(from: sharedDefaults.string(forKey: storageKey) ?? system.rawValue)
    }

    static func localized(_ key: String, defaultValue: String) -> String {
        let selection = current
        if selection == .en || (selection == .system && BibleLanguage.systemDefault == .en) {
            return defaultValue
        }
        let languageCode: String
        switch selection {
        case .system:
            languageCode = Locale.preferredLanguages.first ?? "en"
        case .pt:
            languageCode = "pt-BR"
        case .en:
            languageCode = "en"
        }

        let candidates = [languageCode, Locale(identifier: languageCode).language.languageCode?.identifier]
            .compactMap { $0 }
        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
            }
        }
        return Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    }
}

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    @Published var selection: AppLanguage {
        didSet {
            AppLanguage.sharedDefaults.set(selection.rawValue, forKey: AppLanguage.storageKey)
            refreshWidgetsIfLanguageChanged()
        }
    }

    private init() {
        selection = AppLanguage.selection(
            from: AppLanguage.sharedDefaults.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue
        )
        // Covers a system language change with "System" selected (iOS relaunches the app).
        refreshWidgetsIfLanguageChanged()
    }

    /// The widget keeps its timeline until midnight, so it must be reloaded whenever the effective
    /// language changes; otherwise it only switches after being removed and added again.
    private func refreshWidgetsIfLanguageChanged() {
        let defaults = AppLanguage.sharedDefaults
        let effective = selection.bibleLanguage
        let last = defaults.string(forKey: WidgetLanguageSync.storageKey).flatMap(BibleLanguage.init(rawValue:))
        guard WidgetLanguageSync.needsReload(lastRendered: last, current: effective) else { return }
        defaults.set(effective.rawValue, forKey: WidgetLanguageSync.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Tracks the language the widget was last asked to render in (`zensounds.widget.lastLanguage`).
enum WidgetLanguageSync {
    static let storageKey = "zensounds.widget.lastLanguage"

    static func needsReload(lastRendered: BibleLanguage?, current: BibleLanguage) -> Bool {
        lastRendered != current
    }
}

struct BibleBook: Identifiable, Codable, Hashable {
    let code: String
    let order: Int
    let chapters: Int
    let namePt: String
    let nameEn: String

    enum CodingKeys: String, CodingKey {
        case code, order, chapters
        case namePt = "name_pt"
        case nameEn = "name_en"
    }

    var id: String { code }

    func name(for language: BibleLanguage) -> String {
        language == .pt ? namePt : nameEn
    }
}

struct Verse: Identifiable, Hashable, Codable {
    let book: String
    let chapter: Int
    let number: Int
    let text: String
    let language: BibleLanguage

    var id: String { "\(language.rawValue):\(book):\(chapter):\(number)" }
}

struct DailyReadingRef: Codable, Hashable {
    let book: String
    let chapter: Int
    let verse: Int
}

struct BibleTranslationInfo: Codable, Identifiable {
    let language: String
    let translationId: String
    let source: String
    let licenseUrl: String
    let books: Int
    let chapters: Int
    let verses: Int

    var id: String { language }

    enum CodingKeys: String, CodingKey {
        case language, source, licenseUrl, books, chapters, verses
        case translationId = "id"
    }
}

struct BibleManifest: Codable {
    let schema: Int
    let downloadedOn: String
    let translations: [BibleTranslationInfo]

    func translation(for language: BibleLanguage) -> BibleTranslationInfo? {
        translations.first { $0.language == language.rawValue }
    }
}

/// Raw decoding types mirroring the HelloAO Bible JSON schema bundled from the Android app
/// (`schema: 1`). Kept separate from the app-facing `Verse` model because the source JSON
/// represents verse text as an array of pieces (plain strings or `{lineBreak:true}` markers).
nonisolated enum BibleContentPiece: Decodable {
    case text(String)
    case lineBreak

    private enum CodingKeys: String, CodingKey {
        case text
        case lineBreak
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let string = try? container.decode(String.self) {
            self = .text(string)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            self = .text(text)
        } else if (try container.decodeIfPresent(Bool.self, forKey: .lineBreak)) == true {
            self = .lineBreak
        } else {
            self = .text("")
        }
    }
}

nonisolated struct BibleRawVerseItem: Decodable {
    let number: Int
    let content: [BibleContentPiece]
}

nonisolated enum BibleRawContentItem: Decodable {
    case verse(BibleRawVerseItem)
    /// Psalm superscription ("A Psalm of David…"): real source text, shown above verse 1.
    case subtitle([BibleContentPiece])
    case other

    private enum CodingKeys: String, CodingKey { case type, content }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        switch type {
        case "verse":
            self = .verse(try BibleRawVerseItem(from: decoder))
        case "hebrew_subtitle":
            self = .subtitle(try container.decodeIfPresent([BibleContentPiece].self, forKey: .content) ?? [])
        default:
            self = .other
        }
    }
}

nonisolated struct BibleRawChapterContent: Decodable {
    let number: Int
    let content: [BibleRawContentItem]
}

nonisolated struct BibleRawChapterWrapper: Decodable {
    let numberOfVerses: Int
    let chapter: BibleRawChapterContent
}

nonisolated struct BibleRawBookHeader: Decodable {
    let id: String
    let name: String?
    let commonName: String?
    let order: Int
    let numberOfChapters: Int
}

nonisolated struct BibleRawFile: Decodable {
    let schema: Int
    let book: BibleRawBookHeader
    let chapters: [String: BibleRawChapterWrapper]
}
