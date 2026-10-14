import AVFoundation
import Foundation
import Testing
@testable import ZenSounds

@MainActor
struct RosarySequenceTests {
    private var sets: [RosaryMysterySet] { RosaryRepository.shared.mysterySets }

    @Test func sequenceCountsWithAndWithoutFatima() throws {
        let set = try #require(sets.first)
        let full = RosarySequenceBuilder.build(set: set)
        let short = RosarySequenceBuilder.build(set: set, options: .init(includeFatimaPrayer: false))
        #expect(full.count == 80)
        #expect(short.count == 75)
        #expect(full.filter { $0.prayer == .hailMary }.count == 53)
        #expect(full.filter { $0.prayer == .ourFather }.count == 6)
        #expect(full.filter { $0.prayer == .gloryBe }.count == 6)
        #expect(full.filter { $0.prayer == .fatima }.count == 5)
    }

    @Test func openingDecadesAndClosingUseExactStableOrder() throws {
        let set = try #require(sets.first)
        let steps = RosarySequenceBuilder.build(set: set)
        #expect(steps.prefix(7).map(\.id) == ["opening.signOfCross", "opening.creed", "opening.ourFather", "opening.hailMary.1", "opening.hailMary.2", "opening.hailMary.3", "opening.gloryBe"])
        for decade in 1...5 {
            let decadeSteps = steps.filter { $0.decade == decade }
            #expect(decadeSteps.first?.id == "decade.\(decade).announcement")
            #expect(decadeSteps[1].id == "decade.\(decade).ourFather")
            #expect(decadeSteps.filter { $0.prayer == .hailMary }.count == 10)
            #expect(decadeSteps.suffix(2).map(\.prayer) == [.gloryBe, .fatima])
        }
        #expect(steps.suffix(3).map(\.id) == ["closing.hailHolyQueen", "closing.finalPrayer", "closing.signOfCross"])
    }

    @Test func contentHasFourSetsTwentyUniqueMysteriesAndAllPrayers() {
        #expect(sets.count == 4)
        #expect(sets.allSatisfy { $0.mysteries.count == 5 })
        let mysteries = sets.flatMap(\.mysteries)
        #expect(Set(mysteries.map(\.id)).count == 20)
        #expect(mysteries.allSatisfy { !$0.name.pt.isEmpty && !$0.name.en.isEmpty && !$0.meditation.pt.isEmpty && !$0.meditation.en.isEmpty })
        #expect(mysteries.first { $0.id == "glorious.4" }?.reference == nil)
        #expect(mysteries.first { $0.id == "glorious.5" }?.reference == nil)
        for mystery in mysteries where mystery.reference != nil {
            let reference = mystery.reference!
            let book = BibleCatalog.shared.book(code: reference.book)
            #expect(book != nil)
            #expect(reference.chapter > 0 && reference.chapter <= (book?.chapters ?? 0))
        }
        let prayers = RosaryRepository.shared.prayers
        #expect(prayers.count == 8)
        #expect(prayers.allSatisfy { !$0.pt.isEmpty && !$0.en.isEmpty })
    }

    @Test func manualNavigationHonorsLimitsAndBeadTargets() throws {
        let steps = RosarySequenceBuilder.build(set: try #require(sets.first))
        #expect(RosaryNavigationRules.previousIndex(current: 0) == nil)
        #expect(RosaryNavigationRules.nextIndex(current: 0, count: steps.count) == 1)
        #expect(RosaryNavigationRules.nextIndex(current: steps.count - 1, count: steps.count) == nil)
        #expect(RosaryNavigationRules.firstIndex(for: "loop.2.small.4", in: steps).map { steps[$0].id } == "decade.2.hailMary.4")
    }

    @Test func physicalLoopHasEveryBeadExactlyOnce() {
        let ids = RosaryVisualRules.loopBeadIDs
        #expect(ids.count == 54)
        #expect(Set(ids).count == 54)
        #expect(ids.filter { $0.contains(".small.") }.count == 50)
        #expect(ids.filter { $0.contains(".large.") }.count == 4)
        #expect(ids.first == "loop.1.small.1")
        #expect(ids.last == "loop.5.small.10")
    }

    @Test func reusedCrucifixStaysCompletedUntilClosingPrayer() throws {
        let steps = RosarySequenceBuilder.build(set: try #require(sets.first))
        #expect(RosaryVisualRules.progress(for: "crucifix", in: steps, currentIndex: 0) == .current)
        #expect(RosaryVisualRules.progress(for: "crucifix", in: steps, currentIndex: 2) == .completed)
        #expect(RosaryVisualRules.progress(for: "crucifix", in: steps, currentIndex: steps.count - 1) == .current)
    }
}

struct MysteryScheduleTests {
    @Test func fullWeekMatchesRosariumScheduleRegardlessOfFirstWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        let expected: [RosaryMysterySetID] = [.joyful, .sorrowful, .glorious, .luminous, .sorrowful, .joyful, .glorious]
        for firstWeekday in [1, 2] {
            calendar.firstWeekday = firstWeekday
            for (offset, id) in expected.enumerated() {
                let date = try #require(formatter.date(from: "2026-10-\(12 + offset)"))
                #expect(MysterySchedule.suggestedSet(for: date, calendar: calendar) == id)
            }
        }
    }
}

struct NarrationVoiceRuleTests {
    private func voice(_ id: String, _ name: String, _ language: String, _ quality: NarrationVoiceQuality, novelty: Bool = false, personal: Bool = false) -> VoiceDescriptor {
        VoiceDescriptor(identifier: id, name: name, language: language, quality: quality, isNovelty: novelty, isPersonal: personal)
    }

    @Test func orderingExclusionsAndAutomaticFallbacks() {
        let voices = [
            voice("pt-default", "Ana", "pt-BR", .default),
            voice("pt-premium", "Bia", "pt-BR", .premium),
            voice("pt-pt-enhanced", "Carmo", "pt-PT", .enhanced),
            voice("novelty", "Funny", "pt-BR", .premium, novelty: true),
            voice("personal", "Mine", "pt-BR", .premium, personal: true),
            voice("en", "Alex", "en-US", .premium),
        ]
        let ordered = NarrationVoiceRules.selectorVoices(from: voices, languageCode: "pt", exactLocale: "pt-BR")
        #expect(ordered.map(\.identifier) == ["pt-premium", "pt-pt-enhanced", "pt-default"])
        #expect(NarrationVoiceRules.automaticVoice(from: voices, languageCode: "pt", exactLocale: "pt-BR")?.identifier == "pt-premium")
        #expect(NarrationVoiceRules.automaticVoice(from: [voices[2]], languageCode: "pt", exactLocale: "pt-BR")?.identifier == "pt-pt-enhanced")
        #expect(NarrationVoiceRules.automaticVoice(from: [voices[5]], languageCode: "pt", exactLocale: "pt-BR") == nil)
    }
}

@MainActor
struct RosaryPersistenceTests {
    @Test func roundTripUnknownVersionAndMissingFatimaRestore() throws {
        let suite = "zensounds.rosary.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let store = RosaryProgressStore(defaults: defaults)
        store.save(set: .joyful, stepID: "decade.2.fatima", mode: .guided, includeFatima: true)
        let restored = RosaryProgressStore(defaults: defaults)
        #expect(restored.progress?.currentStepID == "decade.2.fatima")
        let set = try #require(RosaryRepository.shared.mysterySet(.joyful))
        let withoutFatima = RosarySequenceBuilder.build(set: set, options: .init(includeFatimaPrayer: false))
        let index = restored.restoredIndex(in: withoutFatima, saved: try #require(restored.progress))
        #expect(withoutFatima[index].id == "decade.3.announcement")

        defaults.set(Data("broken".utf8), forKey: RosaryProgressStore.storageKey)
        #expect(RosaryProgressStore(defaults: defaults).progress == nil)
        let future = RosarySavedProgress(schemaVersion: 999, mysterySet: .joyful, currentStepID: "opening.creed", mode: .manual, includeFatimaPrayer: true, updatedAt: Date())
        defaults.set(try JSONEncoder().encode(future), forKey: RosaryProgressStore.storageKey)
        #expect(RosaryProgressStore(defaults: defaults).progress == nil)
    }
}

@MainActor
private final class MockNarrationAudio: NarrationAudioCoordinating {
    var prepareCount = 0; var duckValues: [Bool] = []; var finishCount = 0; var succeeds = true
    func prepareAudioSessionForNarration() async -> Bool { prepareCount += 1; return succeeds }
    func setNarrationDucking(_ isDucked: Bool) { duckValues.append(isDucked) }
    func finishNarrationAudioSession() { finishCount += 1 }
}

@MainActor
private final class MockSynthesizer: SpeechSynthesizing {
    var delegate: AVSpeechSynthesizerDelegate?
    var isSpeaking = false; var isPaused = false; var utterance: AVSpeechUtterance?
    func speak(_ utterance: AVSpeechUtterance) { self.utterance = utterance; isSpeaking = true; delegate?.speechSynthesizer?(AVSpeechSynthesizer(), didStart: utterance) }
    func pauseSpeaking(at boundary: AVSpeechBoundary) -> Bool { guard let utterance else { return false }; isSpeaking = false; isPaused = true; delegate?.speechSynthesizer?(AVSpeechSynthesizer(), didPause: utterance); return true }
    func continueSpeaking() -> Bool { guard let utterance else { return false }; isPaused = false; isSpeaking = true; delegate?.speechSynthesizer?(AVSpeechSynthesizer(), didContinue: utterance); return true }
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { guard let utterance else { return false }; isPaused = false; isSpeaking = false; delegate?.speechSynthesizer?(AVSpeechSynthesizer(), didCancel: utterance); return true }
    func finish() { guard let utterance else { return }; isSpeaking = false; delegate?.speechSynthesizer?(AVSpeechSynthesizer(), didFinish: utterance) }
}

@MainActor
private final class MockRosaryNarration: RosaryNarrating {
    var state: BibleNarrationService.PlaybackState = .stopped
    var spokenIDs: [String] = []
    var stopCount = 0
    var pauseCount = 0
    var resumeCount = 0
    private var finishHandler: ((String) -> Void)?
    private var cancelHandler: (() -> Void)?
    private var pauseHandler: (() -> Void)?

    func speakRosary(text: String, itemID: String, language: BibleLanguage, onStart: @escaping () -> Void, onFinish: @escaping (String) -> Void, onCancel: @escaping () -> Void, onPause: @escaping () -> Void) {
        spokenIDs.append(itemID); state = .speaking; finishHandler = onFinish; cancelHandler = onCancel; pauseHandler = onPause; onStart()
    }
    func pause() { pauseCount += 1; state = .paused; pauseHandler?() }
    func resume() { resumeCount += 1; state = .speaking }
    func stop() { stopCount += 1; state = .stopped; cancelHandler?() }
    func finish(_ id: String) { state = .stopped; finishHandler?(id) }
    func cancel() { state = .stopped; cancelHandler?() }
}

@MainActor
struct RosaryGuidedControllerTests {
    @Test func advancesOnlyForCurrentFinishAndIgnoresLateCallbacks() {
        let narration = MockRosaryNarration()
        let controller = RosaryGuidedController(narration: narration)
        var finished: [String] = []
        controller.onStepFinished = { finished.append($0) }
        controller.start(stepID: "one", text: "First", language: .en)
        narration.finish("rosary:wrong")
        #expect(finished.isEmpty)
        narration.finish("rosary:one")
        #expect(finished == ["one"])

        controller.start(stepID: "two", text: "Second", language: .en)
        controller.invalidateSpeech()
        narration.finish("rosary:two")
        #expect(finished == ["one"])
    }

    @Test func pauseResumeStopAndCancelNeverAdvance() {
        let narration = MockRosaryNarration()
        let controller = RosaryGuidedController(narration: narration)
        var finishCount = 0; controller.onStepFinished = { _ in finishCount += 1 }
        controller.start(stepID: "one", text: "First", language: .en)
        controller.pause()
        #expect(controller.state == .paused)
        controller.resume()
        #expect(controller.state == .speaking)
        narration.cancel()
        #expect(controller.state == .paused)
        #expect(finishCount == 0)
        controller.invalidateSpeech(keepingPosition: false)
        #expect(controller.state == .idle)
    }
}
