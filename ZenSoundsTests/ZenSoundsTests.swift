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

@MainActor
struct MixRulesTests {
    @Test func biblicalSoundscapesUseOnlyCatalogSoundsAndUniqueLayers() {
        #expect(BiblicalSoundscapeCatalog.all.count == 4)
        for soundscape in BiblicalSoundscapeCatalog.all {
            let ids = soundscape.layers.map(\.soundId)
            #expect(!ids.isEmpty)
            #expect(Set(ids).count == ids.count)
            #expect(ids.allSatisfy { SoundCatalog.sound(id: $0) != nil })
            #expect(MixRules.normalize(soundscape.layers) == soundscape.layers)
            #expect(BiblicalSoundscapeCatalog.soundscape(forMixID: soundscape.playableMix.id) == soundscape)
            #expect(SoundCatalog.sound(id: soundscape.artworkName) != nil)
        }
    }

    @Test func priorityExpansionSoundsAreAvailableInTheNatureCatalog() {
        let expected = ["GalileeWaves", "MeadowSheep", "OliveGrove", "MorningBirds"]
        for id in expected {
            #expect(SoundCatalog.sound(id: id)?.category == .nature)
        }
    }

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
        #expect(normalized.count == min(MixRules.maxLayers, SoundCatalog.all.count))
    }

    @Test func removedSoundsAreUnavailableAndFilteredFromLegacyMixes() {
        #expect(SoundCatalog.sound(id: "CarEngine") == nil)
        #expect(SoundCatalog.sound(id: "TVStatic") == nil)

        let legacyMixes = [
            SavedMix(id: "mixed", name: "Mixed", layers: [
                MixLayer(soundId: "Rain", volume: 0.8),
                MixLayer(soundId: "TVStatic", volume: 0.2),
            ]),
            SavedMix(id: "removed", name: "Removed", layers: [
                MixLayer(soundId: "CarEngine", volume: 1),
            ]),
        ]
        let sanitized = UserPreferencesStore.removingUnavailableSounds(from: legacyMixes)

        #expect(sanitized.count == 1)
        #expect(sanitized[0].id == "mixed")
        #expect(sanitized[0].layers.map(\.soundId) == ["Rain"])
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

struct NarrationRateRulesTests {
    @Test func clampsRateToSupportedRange() {
        #expect(NarrationRateRules.clamped(0.1) == NarrationRateRules.range.lowerBound)
        #expect(NarrationRateRules.clamped(0.9) == NarrationRateRules.range.upperBound)
        #expect(NarrationRateRules.clamped(0.5) == 0.5)
    }
}

struct AudioStabilityRulesTests {
    @Test func transportTransitionsBetweenStoppedPlayingAndPaused() {
        var state = AudioTransportRules.nextState(from: .stopped, event: .startSucceeded)
        #expect(state == .playing)
        state = AudioTransportRules.nextState(from: state, event: .pause)
        #expect(state == .paused)
        state = AudioTransportRules.nextState(from: state, event: .resumeSucceeded)
        #expect(state == .playing)
        state = AudioTransportRules.nextState(from: state, event: .stop)
        #expect(state == .stopped)
    }

    @Test func failedReplacementPreservesPreviousValidState() {
        #expect(AudioTransportRules.nextState(from: .playing, event: .startFailed) == .playing)
        #expect(AudioTransportRules.nextState(from: .paused, event: .startFailed) == .paused)
    }

    @Test func timerExpirationPausesWithoutDiscardingPlaybackState() {
        #expect(AudioTransportRules.nextState(from: .playing, event: .timerExpired) == .paused)
        #expect(AudioTransportRules.nextState(from: .paused, event: .timerExpired) == .paused)
    }

    @Test func operationGenerationRejectsStoppedAndSupersededWork() {
        var generation = OperationGeneration()
        let first = generation.begin()
        let second = generation.begin()
        #expect(!generation.isCurrent(first))
        #expect(generation.isCurrent(second))
        generation.invalidate()
        #expect(!generation.isCurrent(second))
    }

    @Test func duckingIsTemporaryAndPreservesLayerProportions() {
        let rain = AudioGainRules.effectiveGain(baseGain: 0.8, duckMultiplier: AudioGainRules.narrationDuckMultiplier)
        let forest = AudioGainRules.effectiveGain(baseGain: 0.4, duckMultiplier: AudioGainRules.narrationDuckMultiplier)
        #expect(abs(rain - 0.24) < 0.0001)
        #expect(abs(forest - 0.12) < 0.0001)
        #expect(abs((rain / forest) - 2) < 0.0001)
        #expect(AudioGainRules.effectiveGain(baseGain: 0.65, duckMultiplier: 1) == 0.65)
    }

    @Test func userVolumeChangeDuringDuckingUsesTheNewBaseGain() {
        let updated = AudioGainRules.effectiveGain(baseGain: 0.5, duckMultiplier: 0.3)
        #expect(abs(updated - 0.15) < 0.0001)
        #expect(AudioGainRules.effectiveGain(baseGain: 0.5, duckMultiplier: 1) == 0.5)
    }
}

@MainActor
struct NarrationStateRulesTests {
    @Test func narrationStateTransitionsCoverPauseResumeFinishAndCancel() {
        #expect(BibleNarrationService.nextState(after: .started) == .speaking)
        #expect(BibleNarrationService.nextState(after: .paused) == .paused)
        #expect(BibleNarrationService.nextState(after: .resumed) == .speaking)
        #expect(BibleNarrationService.nextState(after: .finished) == .stopped)
        #expect(BibleNarrationService.nextState(after: .cancelled) == .stopped)
        #expect(BibleNarrationService.nextState(after: .failed) == .stopped)
    }

    @Test func voiceSelectionUsesInstalledPreferenceOrFallsBack() {
        let voices = ["voice.pt.default", "voice.pt.enhanced"]
        #expect(NarrationVoiceRules.resolvedIdentifier(
            preferredIdentifier: "voice.pt.enhanced",
            availableIdentifiers: voices
        ) == "voice.pt.enhanced")
        #expect(NarrationVoiceRules.resolvedIdentifier(
            preferredIdentifier: "voice.removed",
            availableIdentifiers: voices
        ) == "voice.pt.default")
        #expect(NarrationVoiceRules.resolvedIdentifier(
            preferredIdentifier: nil,
            availableIdentifiers: []
        ) == nil)
    }
}

struct WidgetIntegrationRulesTests {
    @Test func appGroupSelectionPersistsUsingTheWidgetContract() {
        let suiteName = "zensounds.widget.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DailyWordStore(defaults: defaults)
        let readings = [DailyReadingRef(book: "JHN", chapter: 3, verse: 16)]

        let selected = store.reference(for: Date(timeIntervalSince1970: 1_700_000_000), readings: readings)

        #expect(selected == readings[0])
        #expect(defaults.string(forKey: "daily_word_book") == "JHN")
        #expect(defaults.integer(forKey: "daily_word_chapter") == 3)
        #expect(defaults.integer(forKey: "daily_word_verse") == 16)
    }

    @Test func widgetDeepLinkRoundTripsAndRejectsInvalidRoutes() {
        let route = BibleDeepLink(book: "PSA", chapter: 23, verse: 1)
        #expect(route.url.flatMap(BibleDeepLink.parse) == route)
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/PSA/0/1")!) == nil)
        #expect(BibleDeepLink.parse(URL(string: "https://example.com/chapter/PSA/23/1")!) == nil)
    }

    @Test func systemAndExplicitLanguageSelectionsResolveConsistently() {
        #expect(AppLanguage.selection(from: "pt").bibleLanguage == .pt)
        #expect(AppLanguage.selection(from: "en").bibleLanguage == .en)
        #expect(AppLanguage.selection(from: "unknown") == .system)
    }
}
