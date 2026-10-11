import Testing
import Foundation
@testable import ZenSounds

struct BibleRepositoryTests {
    @Test func psalm23HasSixVersesInPortuguese() {
        let verses = BibleRepository.shared.chapter(bookCode: "PSA", number: 23, language: .pt)
        #expect(verses.count == 6)
        #expect(verses.first?.text.contains("SENHOR") == true)
    }

    @Test func john316ExistsInEnglish() {
        let verse = BibleRepository.shared.verse(bookCode: "JHN", chapter: 3, number: 16, language: .en)
        #expect(verse != nil)
        #expect(verse?.text.isEmpty == false)
    }

    @Test func catalogHasAllSixtySixBooksInCanonicalOrder() {
        #expect(BibleCatalog.shared.books.count == 66)
        #expect(BibleCatalog.shared.books.first?.code == "GEN")
        #expect(BibleCatalog.shared.books.last?.code == "REV")
    }

    @Test func dailyReadingsCatalogIsFullyLoaded() {
        #expect(BibleCatalog.shared.dailyReadings.count == 132)
    }
}

struct DailyWordStoreTests {
    private func freshStore() -> DailyWordStore {
        DailyWordStore(defaults: UserDefaults(suiteName: "zensounds.tests.\(UUID().uuidString)")!)
    }

    @Test func selectionIsStableForTheSameLocalDay() {
        let readings = BibleCatalog.shared.dailyReadings
        let store = freshStore()
        let date = Date()
        let first = store.reference(for: date, readings: readings)
        let second = store.reference(for: date, readings: readings)
        #expect(first == second)
    }

    @Test func shuffleNeverImmediatelyRepeatsTheCurrentReading() {
        let readings = BibleCatalog.shared.dailyReadings
        let store = freshStore()
        let current = store.reference(for: Date(), readings: readings)
        let shuffled = store.shuffle(current: current, readings: readings, date: Date())
        #expect(shuffled != current)
    }

    @Test func deterministicReadingIsPureAndRepeatable() {
        let readings = BibleCatalog.shared.dailyReadings
        let date = Date()
        let a = DailyWordStore.deterministicReading(for: date, readings: readings)
        let b = DailyWordStore.deterministicReading(for: date, readings: readings)
        #expect(a == b)
    }
}

struct MixRulesTests {
    @Test func normalizeDedupesUnknownSoundsAndClampsVolume() {
        let layers = [
            MixLayer(soundId: "Rain", volume: 1.5),
            MixLayer(soundId: "Rain", volume: 0.2),
            MixLayer(soundId: "NotASound", volume: 0.5),
            MixLayer(soundId: "Storm", volume: -0.3),
        ]
        let normalized = MixRules.normalize(layers)
        #expect(normalized.count == 2)
        #expect(normalized.first?.soundId == "Rain")
        #expect(normalized.first?.volume == 1.0)
        #expect(normalized.last?.volume == 0.0)
    }

    @Test func normalizeCapsAtMaxLayers() {
        let layers = SoundCatalog.all.map { MixLayer(soundId: $0.id, volume: 1.0) } + [MixLayer(soundId: "Rain", volume: 1.0)]
        let normalized = MixRules.normalize(layers)
        #expect(normalized.count == MixRules.maxLayers)
    }

    @Test func gainsSumToMasterVolumeRegardlessOfLayerCount() {
        let layers = [MixLayer(soundId: "Rain", volume: 1.0), MixLayer(soundId: "Storm", volume: 1.0)]
        let gains = MixRules.gains(layers: layers, master: 0.8, fade: 1.0)
        for gain in gains.values {
            #expect(gain <= 0.8 + 0.0001)
        }
        let total = gains.values.reduce(0, +)
        #expect(abs(total - 0.8) < 0.0001)
    }
}

struct TimerRulesTests {
    @Test func durationRejectsOutOfRangeMinutes() {
        #expect(TimerRules.durationSeconds(minutes: 0) == nil)
        #expect(TimerRules.durationSeconds(minutes: 1441) == nil)
        #expect(TimerRules.durationSeconds(minutes: 30) == 1800)
    }

    @Test func remainingNeverGoesNegative() {
        #expect(TimerRules.remaining(deadline: 100, now: 150) == 0)
        #expect(TimerRules.remaining(deadline: 150, now: 100) == 50)
    }

    @Test func fadeMultiplierIsLinearWithinTheFadeWindow() {
        let deadline: TimeInterval = 100
        #expect(TimerRules.fadeMultiplier(deadline: deadline, now: 95, fadeSeconds: 10) == 0.5)
        #expect(TimerRules.fadeMultiplier(deadline: deadline, now: 100, fadeSeconds: 10) == 0.0)
        #expect(TimerRules.fadeMultiplier(deadline: deadline, now: 50, fadeSeconds: 0) == 1.0)
    }
}
