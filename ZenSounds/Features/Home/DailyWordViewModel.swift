import SwiftUI
import Combine
import WidgetKit

@MainActor
final class DailyWordViewModel: ObservableObject {
    struct State {
        var reading: DailyReadingRef?
        var verse: Verse?
        var isLoading = true
    }

    @Published private(set) var state = State()
    var language: BibleLanguage { AppLanguageStore.shared.selection.bibleLanguage }

    private var lastLoadKey: String?
    private var loadTask: Task<Void, Never>?

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
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func apply(reading: DailyReadingRef, force: Bool = false) {
        let key = "\(reading.book):\(reading.chapter):\(reading.verse):\(language.rawValue)"
        guard force || key != lastLoadKey else { return }
        lastLoadKey = key
        state = State(reading: reading, verse: nil, isLoading: true)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let verse = await BibleRepository.shared.verseAsync(
                bookCode: reading.book,
                chapter: reading.chapter,
                number: reading.verse,
                language: language
            )
            guard !Task.isCancelled else { return }
            state = State(reading: reading, verse: verse, isLoading: false)
        }
    }
}
