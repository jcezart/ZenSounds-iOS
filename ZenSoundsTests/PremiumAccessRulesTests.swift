import Testing
import Foundation
@testable import ZenSounds

@MainActor
struct PremiumAccessRulesTests {
    @Test(arguments: 0..<11)
    func completeSoundMatrix(index: Int) {
        #expect(SoundCatalog.all.count == 11, "Update the parameter range when adding a sound")
        let soundID = SoundCatalog.all[index].id
        let expectedFree = Set(["Rain", "Forest", "Stream"])
        #expect(PremiumAccessRules.isFreeSound(soundID) == expectedFree.contains(soundID))
    }

    @Test(arguments: 0..<4)
    func completeSoundscapeMatrix(index: Int) {
        #expect(BiblicalSoundscapeCatalog.all.count == 4, "Update the parameter range when adding a soundscape")
        let soundscapeID = BiblicalSoundscapeCatalog.all[index].id
        #expect(PremiumAccessRules.isFreeSoundscape(soundscapeID) == (soundscapeID == "good-shepherd"))
    }

    @Test(arguments: ["terracotta", "forest", "midnight", "plum", "ocean"])
    func completeWidgetThemeMatrix(themeID: String) {
        #expect(PremiumAccessRules.requiresPlus(for: .widgetTheme(id: themeID)) == (themeID != "terracotta"))
    }

    @Test(arguments: [5, 15, 30, 60])
    func timerPresetsAreFree(minutes: Int) {
        #expect(PremiumAccessRules.isFreeTimerPreset(minutes))
    }

    @Test func remainingFeatureMatrixMatchesOrantePlusSpecification() {
        #expect(!PremiumAccessRules.requiresPlus(for: .verseNarration(isDailyWord: true)))
        #expect(PremiumAccessRules.requiresPlus(for: .verseNarration(isDailyWord: false)))
        #expect(PremiumAccessRules.requiresPlus(for: .mixer))
        #expect(PremiumAccessRules.requiresPlus(for: .savedMix))
        #expect(PremiumAccessRules.requiresPlus(for: .customTimer))
        #expect(PremiumAccessRules.requiresPlus(for: .guidedRosary))
    }

    @Test func gateRunsFreeFeaturesWithoutAPlacementEvenWhileUnknown() {
        let entitlement = EntitlementMock(state: .unknown, hasPlus: false)
        var placements: [PremiumPlacement] = []
        var performed = false
        let gate = PremiumGate(entitlements: entitlement) { placement, _ in placements.append(placement) }

        gate.gate(.sound(id: "Rain"), parameters: ["sound_id": "Rain"]) { performed = true }

        #expect(performed)
        #expect(placements.isEmpty)
        #expect(!gate.shouldShowBadge(for: .sound(id: "Storm")))
    }

    @Test(arguments: [
        PlacementCase(
            feature: .sound(id: "Storm"),
            parameters: ["sound_id": "Storm"],
            expected: PremiumPlacement(name: "premium_sound", parameters: ["sound_id": "Storm"])
        ),
        PlacementCase(
            feature: .soundscape(id: "peace-in-galilee"),
            parameters: ["soundscape_id": "peace-in-galilee"],
            expected: PremiumPlacement(
                name: "premium_soundscape",
                parameters: ["soundscape_id": "peace-in-galilee"]
            )
        ),
        PlacementCase(
            feature: .mixer,
            parameters: ["source": "library"],
            expected: PremiumPlacement(name: "create_mix", parameters: ["source": "library"])
        ),
        PlacementCase(
            feature: .savedMix,
            parameters: ["source": "saved_mix"],
            expected: PremiumPlacement(name: "create_mix", parameters: ["source": "saved_mix"])
        ),
        PlacementCase(
            feature: .verseNarration(isDailyWord: false),
            parameters: ["book": "PSA", "chapter": "23"],
            expected: PremiumPlacement(
                name: "bible_narration",
                parameters: ["book": "PSA", "chapter": "23"]
            )
        ),
        PlacementCase(
            feature: .guidedRosary,
            parameters: [:],
            expected: PremiumPlacement(name: "guided_rosary", parameters: [:])
        ),
        PlacementCase(
            feature: .customTimer,
            parameters: [:],
            expected: PremiumPlacement(name: "custom_timer", parameters: [:])
        ),
        PlacementCase(
            feature: .widgetTheme(id: "forest"),
            parameters: [:],
            expected: PremiumPlacement(name: "widget_theme", parameters: [:])
        )
    ])
    func paidFeatureRegistersExactPlacement(testCase: PlacementCase) {
        let entitlement = EntitlementMock(state: .inactive, hasPlus: false)
        var captured: PremiumPlacement?
        var deferredFeature: (() -> Void)?
        var performed = false
        let gate = PremiumGate(entitlements: entitlement) { placement, feature in
            captured = placement
            deferredFeature = feature
        }

        gate.gate(testCase.feature, parameters: testCase.parameters) { performed = true }

        #expect(captured == testCase.expected)
        #expect(!performed)
        deferredFeature?()
        #expect(performed)
    }

    @Test func paidFeatureWhileUnknownRegistersAndDoesNotExecuteDirectly() {
        let entitlement = EntitlementMock(state: .unknown, hasPlus: false)
        var captured: PremiumPlacement?
        var performed = false
        let gate = PremiumGate(entitlements: entitlement) { placement, _ in captured = placement }

        gate.gate(.customTimer) { performed = true }

        #expect(captured == PremiumPlacement(name: "custom_timer", parameters: [:]))
        #expect(!performed)
        #expect(!gate.shouldShowBadge(for: .customTimer))
    }

    @Test func subscriberRunsPaidFeatureWithoutPlacement() {
        let entitlement = EntitlementMock(state: .active, hasPlus: true)
        var placementCount = 0
        var performed = false
        let gate = PremiumGate(entitlements: entitlement) { _, _ in placementCount += 1 }

        gate.gate(.savedMix) { performed = true }

        #expect(performed)
        #expect(placementCount == 0)
    }

    @Test func audioSafetyRejectsPaidStartsButAllowsFreeStarts() {
        #expect(AudioPremiumSafety.canStartSound(id: "Rain", hasPlus: false))
        #expect(!AudioPremiumSafety.canStartSound(id: "Storm", hasPlus: false))
        #expect(AudioPremiumSafety.canStartMix(id: "official.good-shepherd", hasPlus: false))
        #expect(!AudioPremiumSafety.canStartMix(id: "official.peace-in-galilee", hasPlus: false))
        #expect(!AudioPremiumSafety.canStartMix(id: UUID().uuidString, hasPlus: false))
    }

    @Test func downgradePreservesCurrentPaidPlaybackAndRejectsNextPlay() {
        var activeSoundID: String? = "Storm"
        let active = EntitlementCacheRules.resolve(status: .active, plusIsActive: true, cachedPlus: false)
        #expect(active.hasPlus)

        let inactive = EntitlementCacheRules.resolve(
            status: .inactive,
            cachedPlus: active.cachedPlus
        )
        activeSoundID = AudioPremiumSafety.playbackAfterEntitlementChange(currentSoundID: activeSoundID)
        #expect(activeSoundID == "Storm")

        let nextDecision = AudioPremiumSafety.decisionForSoundStart(id: "Wind", hasPlus: inactive.hasPlus)
        if nextDecision == .startRequestedSound {
            activeSoundID = "Wind"
        }
        #expect(nextDecision == .keepCurrentPlayback)
        #expect(activeSoundID == "Storm")
    }

    @Test func entitlementCacheSurvivesUnknownAndClearsOnConfirmedInactive() {
        let confirmedPlus = EntitlementCacheRules.resolve(
            status: .active,
            plusIsActive: true,
            cachedPlus: false
        )
        #expect(confirmedPlus.hasPlus)
        #expect(confirmedPlus.cachedPlus)

        let offline = EntitlementCacheRules.resolve(
            status: .unknown,
            cachedPlus: confirmedPlus.cachedPlus
        )
        #expect(offline.state == .unknown)
        #expect(offline.hasPlus)
        #expect(offline.cachedPlus)

        let inactive = EntitlementCacheRules.resolve(
            status: .inactive,
            cachedPlus: offline.cachedPlus
        )
        #expect(!inactive.hasPlus)
        #expect(!inactive.cachedPlus)
    }

    @Test(arguments: ["terracotta", "forest", "midnight", "plum", "ocean"])
    func inactiveWidgetAlwaysDisplaysTerracotta(selectedThemeID: String) {
        #expect(PremiumAccessRules.resolvedWidgetThemeID(selectedThemeID, hasPlus: false) == "terracotta")
    }

    @Test func trialReminderIsFiveDaysAfterTrialStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = calendar.date(byAdding: .day, value: 5, to: start)
        #expect(TrialReminderRules.reminderDate(startedAt: start, calendar: calendar) == expected)
    }

    @Test func onboardingAppearsOnceAndDeepLinkDefersIt() throws {
        let suite = "OnboardingStateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let firstLaunch = OnboardingState(defaults: defaults)
        #expect(firstLaunch.shouldPresent)
        firstLaunch.suppressForCurrentLaunch()
        #expect(!firstLaunch.shouldPresent)

        let nextLaunch = OnboardingState(defaults: defaults)
        #expect(nextLaunch.shouldPresent)
        nextLaunch.markSeen()
        #expect(!OnboardingState(defaults: defaults).shouldPresent)
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
struct VerseNarrationStarterTests {
    private let verse = Verse(book: "PSA", chapter: 23, number: 1, text: "Test", language: .en)

    @Test func nonSubscriberVerseNarrationRegistersBibleNarrationAndDoesNotSpeak() {
        var placements: [PremiumPlacement] = []
        var spoken: [Verse] = []
        let gate = PremiumGate(entitlements: EntitlementMock(state: .inactive, hasPlus: false)) { placement, _ in
            placements.append(placement)
        }

        VerseNarrationStarter.start(verse, isDailyWord: false, gate: gate) { spoken.append($0) }

        #expect(placements == [PremiumPlacement(name: "bible_narration", parameters: ["book": "PSA", "chapter": "23"])])
        #expect(spoken.isEmpty)
    }

    @Test func dailyWordNarrationSpeaksWithoutPlacement() {
        var placements: [PremiumPlacement] = []
        var spoken: [Verse] = []
        let gate = PremiumGate(entitlements: EntitlementMock(state: .inactive, hasPlus: false)) { placement, _ in
            placements.append(placement)
        }

        VerseNarrationStarter.start(verse, isDailyWord: true, gate: gate) { spoken.append($0) }

        #expect(placements.isEmpty)
        #expect(spoken == [verse])
    }

    @Test func subscriberVerseNarrationSpeaksWithoutPlacement() {
        var placementCount = 0
        var spoken: [Verse] = []
        let gate = PremiumGate(entitlements: EntitlementMock(state: .active, hasPlus: true)) { _, _ in
            placementCount += 1
        }

        VerseNarrationStarter.start(verse, isDailyWord: false, gate: gate) { spoken.append($0) }

        #expect(placementCount == 0)
        #expect(spoken == [verse])
    }
}

struct PlacementCase: Sendable {
    let feature: PremiumFeature
    let parameters: [String: String]
    let expected: PremiumPlacement
}

@MainActor
private final class EntitlementMock: EntitlementProviding {
    let entitlementState: EntitlementState
    let hasPlus: Bool

    init(state: EntitlementState, hasPlus: Bool) {
        entitlementState = state
        self.hasPlus = hasPlus
    }
}
