import Foundation

/// Persists the Word-of-the-Day selection (including manual "sortear outra" overrides) in the
/// shared App Group container so the main app and the widget extension always agree on the
/// same reference. Mirrors the Android `DailyWordStore` (SharedPreferences-based): the choice
/// is stable for the current local day and recalculated once the local date changes.
final class DailyWordStore {
    static let appGroupID = "group.com.juliocezar.zensounds"
    static let shared = DailyWordStore()

    private let defaults: UserDefaults
    private let dateKey = "daily_word_date"
    private let bookKey = "daily_word_book"
    private let chapterKey = "daily_word_chapter"
    private let verseKey = "daily_word_verse"

    init(defaults: UserDefaults = UserDefaults(suiteName: DailyWordStore.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    /// Returns today's reference, reusing a previously persisted/shuffled choice if the local
    /// date has not changed yet; otherwise recalculates deterministically from `readings`.
    func reference(for date: Date, readings: [DailyReadingRef]) -> DailyReadingRef {
        guard !readings.isEmpty else { return DailyReadingRef(book: "PSA", chapter: 23, verse: 1) }
        let key = Self.dayKey(date)
        if defaults.string(forKey: dateKey) == key, let book = defaults.string(forKey: bookKey) {
            return DailyReadingRef(
                book: book,
                chapter: defaults.integer(forKey: chapterKey),
                verse: defaults.integer(forKey: verseKey)
            )
        }
        let computed = Self.deterministicReading(for: date, readings: readings)
        persist(computed, date: date)
        return computed
    }

    /// Picks a different reading than `current` and persists it for the rest of the local day.
    @discardableResult
    func shuffle(current: DailyReadingRef, readings: [DailyReadingRef], date: Date) -> DailyReadingRef {
        guard readings.count > 1 else { return current }
        var candidate = current
        while candidate == current {
            candidate = readings.randomElement() ?? current
        }
        persist(candidate, date: date)
        return candidate
    }

    private func persist(_ reading: DailyReadingRef, date: Date) {
        defaults.set(Self.dayKey(date), forKey: dateKey)
        defaults.set(reading.book, forKey: bookKey)
        defaults.set(reading.chapter, forKey: chapterKey)
        defaults.set(reading.verse, forKey: verseKey)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func deterministicReading(for date: Date, readings: [DailyReadingRef]) -> DailyReadingRef {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let epochDay = Int(startOfDay.timeIntervalSince1970 / 86400)
        let index = ((epochDay % readings.count) + readings.count) % readings.count
        return readings[index]
    }
}
