import AppIntents
import WidgetKit

/// Interactive widget button action (iOS 17+ `Button(intent:)`): picks a different curated
/// verse than the one currently shown and persists it to the shared App Group container, then
/// asks WidgetKit to reload — the app, if open, will pick up the same change next time its
/// Home screen recomputes (same storage, same keys).
struct ShuffleDailyWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Show another verse"
    static var description = IntentDescription("Shows a different Word of the Day verse.")

    func perform() async throws -> some IntentResult {
        let store = WidgetDailyWordStore()
        let readings = WidgetDataSource.shared.readings
        let current = store.reference(for: Date(), readings: readings)
        store.shuffle(current: current, readings: readings, date: Date())
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
