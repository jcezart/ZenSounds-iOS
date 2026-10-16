import Foundation

/// Old/New Testament split used by the Bible tab's segmented control (canonical order 1–39 = OT).
enum BibleTestament: String, CaseIterable, Identifiable, Hashable {
    case old
    case new

    static let lastOldTestamentOrder = 39

    var id: String { rawValue }

    static func of(_ book: BibleBook) -> BibleTestament {
        book.order <= lastOldTestamentOrder ? .old : .new
    }

    func books(from all: [BibleBook]) -> [BibleBook] {
        all.filter { Self.of($0) == self }.sorted { $0.order < $1.order }
    }
}

/// A chapter of a book, used by the reader to move across chapters (and across books at the edges).
struct ChapterLocation: Hashable {
    let bookCode: String
    let chapter: Int
}

enum ChapterNavigation {
    /// Previous chapter; the last chapter of the previous book at a book's start; nil at Genesis 1.
    static func previous(of location: ChapterLocation, in books: [BibleBook]) -> ChapterLocation? {
        let ordered = books.sorted { $0.order < $1.order }
        guard let index = ordered.firstIndex(where: { $0.code == location.bookCode }) else { return nil }
        if location.chapter > 1 {
            return ChapterLocation(bookCode: location.bookCode, chapter: location.chapter - 1)
        }
        guard index > ordered.startIndex else { return nil }
        let previousBook = ordered[ordered.index(before: index)]
        return ChapterLocation(bookCode: previousBook.code, chapter: previousBook.chapters)
    }

    /// Next chapter; the first chapter of the next book at a book's end; nil at the last chapter of Revelation.
    static func next(of location: ChapterLocation, in books: [BibleBook]) -> ChapterLocation? {
        let ordered = books.sorted { $0.order < $1.order }
        guard let index = ordered.firstIndex(where: { $0.code == location.bookCode }) else { return nil }
        if location.chapter < ordered[index].chapters {
            return ChapterLocation(bookCode: location.bookCode, chapter: location.chapter + 1)
        }
        let nextIndex = ordered.index(after: index)
        guard nextIndex < ordered.endIndex else { return nil }
        return ChapterLocation(bookCode: ordered[nextIndex].code, chapter: 1)
    }
}

/// Reader text size ("Aa"), a multiplier on top of Dynamic Type. Persisted in `zensounds.reading.fontScale`.
enum ReadingFontScale {
    static let storageKey = "zensounds.reading.fontScale"
    static let steps: [Double] = [0.85, 1.0, 1.15, 1.3, 1.5]
    static let defaultValue = 1.0

    /// Snaps any stored value to the nearest step (handles corrupt or legacy values).
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return defaultValue }
        return steps.min { abs($0 - value) < abs($1 - value) } ?? defaultValue
    }

    static func larger(than value: Double) -> Double? {
        steps.first { $0 > clamped(value) }
    }

    static func smaller(than value: Double) -> Double? {
        steps.last { $0 < clamped(value) }
    }
}

enum ChapterShareText {
    /// "Salmos 23", the verses with their numbers, then the app name.
    static func make(title: String, verses: [Verse]) -> String {
        let body = verses.map { "\($0.number) \($0.text)" }.joined(separator: "\n")
        return "\(title)\n\n\(body)\n\n— Orante"
    }
}
