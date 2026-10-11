import SwiftUI
import Combine

@MainActor
final class DailyWordViewModel: ObservableObject {
    struct State {
        var reading: DailyReadingRef?
        var verse: Verse?
        var isLoading = true
    }

    @Published private(set) var state = State()
    @AppStorage(BibleLanguage.storageKey) private var languageRaw = BibleLanguage.systemDefault.rawValue

    var language: BibleLanguage { BibleLanguage(rawValue: languageRaw) ?? .systemDefault }

    private var lastLoadKey: String?

    func refresh() {
        let readings = BibleCatalog.shared.dailyReadings
        let reading = DailyWordStore.shared.reference(for: Date(), readings: readings)
        apply(reading: reading)
    }

    func shuffle() {
        let readings = BibleCatalog.shared.dailyReadings
        guard let current = state.reading else { return }
        let next = DailyWordStore.shared.shuffle(current: current, readings: readings, date: Date())
        apply(reading: next, force: true)
    }

    private func apply(reading: DailyReadingRef, force: Bool = false) {
        let key = "\(reading.book):\(reading.chapter):\(reading.verse):\(language.rawValue)"
        guard force || key != lastLoadKey else { return }
        lastLoadKey = key
        let verse = BibleRepository.shared.verse(bookCode: reading.book, chapter: reading.chapter, number: reading.verse, language: language)
        state = State(reading: reading, verse: verse, isLoading: false)
    }
}
