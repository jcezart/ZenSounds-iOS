import Foundation

struct WidgetReadingRef: Equatable {
    let book: String
    let chapter: Int
    let verse: Int
}

/// Re-implements the main app's `DailyWordStore` key scheme (same App Group suite, same key
/// names, same local-day logic) so both processes always agree on today's selection without
/// sharing Swift source across targets. Keep this in sync with
/// `MyApp/Core/Services/DailyWordStore.swift` if those keys ever change.
struct WidgetDailyWordStore {
    static let appGroupID = "group.com.juliocezar.zensounds"
    private static let dateKey = "daily_word_date"
    private static let bookKey = "daily_word_book"
    private static let chapterKey = "daily_word_chapter"
    private static let verseKey = "daily_word_verse"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: WidgetDailyWordStore.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    func reference(for date: Date, readings: [DailyReadingText]) -> WidgetReadingRef {
        guard !readings.isEmpty else { return WidgetReadingRef(book: "PSA", chapter: 23, verse: 1) }
        let key = Self.dayKey(date)
        if defaults.string(forKey: Self.dateKey) == key, let book = defaults.string(forKey: Self.bookKey) {
            return WidgetReadingRef(
                book: book,
                chapter: defaults.integer(forKey: Self.chapterKey),
                verse: defaults.integer(forKey: Self.verseKey)
            )
        }
        let computed = Self.deterministicReading(for: date, readings: readings)
        persist(computed, date: date)
        return computed
    }

    @discardableResult
    func shuffle(current: WidgetReadingRef, readings: [DailyReadingText], date: Date) -> WidgetReadingRef {
        guard readings.count > 1 else { return current }
        var candidate = current
        while candidate == current {
            guard let r = readings.randomElement() else { break }
            candidate = WidgetReadingRef(book: r.book, chapter: r.chapter, verse: r.verse)
        }
        persist(candidate, date: date)
        return candidate
    }

    private func persist(_ reading: WidgetReadingRef, date: Date) {
        defaults.set(Self.dayKey(date), forKey: Self.dateKey)
        defaults.set(reading.book, forKey: Self.bookKey)
        defaults.set(reading.chapter, forKey: Self.chapterKey)
        defaults.set(reading.verse, forKey: Self.verseKey)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func deterministicReading(for date: Date, readings: [DailyReadingText]) -> WidgetReadingRef {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let epochDay = Int(startOfDay.timeIntervalSince1970 / 86400)
        let index = ((epochDay % readings.count) + readings.count) % readings.count
        let r = readings[index]
        return WidgetReadingRef(book: r.book, chapter: r.chapter, verse: r.verse)
    }
}
