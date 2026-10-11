import Foundation

enum BibleLanguage: String, Codable, CaseIterable, Identifiable {
    case pt
    case en

    var id: String { rawValue }

    static let storageKey = "zensounds.bible_language"

    static var systemDefault: BibleLanguage {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") == true ? .pt : .en
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
enum BibleContentPiece: Decodable {
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

struct BibleRawVerseItem: Decodable {
    let number: Int
    let content: [BibleContentPiece]
}

enum BibleRawContentItem: Decodable {
    case verse(BibleRawVerseItem)
    case other

    private enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        if type == "verse" {
            self = .verse(try BibleRawVerseItem(from: decoder))
        } else {
            self = .other
        }
    }
}

struct BibleRawChapterContent: Decodable {
    let number: Int
    let content: [BibleRawContentItem]
}

struct BibleRawChapterWrapper: Decodable {
    let numberOfVerses: Int
    let chapter: BibleRawChapterContent
}

struct BibleRawBookHeader: Decodable {
    let id: String
    let name: String?
    let commonName: String?
    let order: Int
    let numberOfChapters: Int
}

struct BibleRawFile: Decodable {
    let schema: Int
    let book: BibleRawBookHeader
    let chapters: [String: BibleRawChapterWrapper]
}
