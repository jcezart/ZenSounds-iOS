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
        var deliverOutcome: ((PaywallOutcome) -> Void)?
        var performed = false
        let gate = PremiumGate(entitlements: entitlement) { placement, onOutcome in
            captured = placement
            deliverOutcome = onOutcome
        }

        gate.gate(testCase.feature, parameters: testCase.parameters) { performed = true }

        #expect(captured == testCase.expected)
        #expect(!performed)
        // Purchase completed on the paywall and the entitlement is already active.
        entitlement.hasPlus = true
        entitlement.entitlementState = .active
        deliverOutcome?(PaywallOutcome(paywallPresented: true, purchasedOrRestored: true))
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

/// Every paid feature, re-checked by the gate after Superwall answers (Superwall releases the
/// feature when the placement isn't found, so it must never be trusted on its own).
@MainActor
struct PremiumGateOutcomeTests {
    nonisolated static let paidFeatures: [PremiumFeature] = [
        .sound(id: "Storm"),
        .soundscape(id: "peace-in-galilee"),
        .mixer,
        .savedMix,
        .customTimer,
        .verseNarration(isDailyWord: false),
        .guidedRosary,
        .widgetTheme(id: "forest"),
        .upgrade,
    ]

    /// Placement each paid feature registers (one per Superwall placement used by the app).
    nonisolated static let expectedPlacements: [String] = [
        "premium_sound", "premium_soundscape", "create_mix", "create_mix", "custom_timer",
        "bible_narration", "guided_rosary", "widget_theme", "settings_upgrade",
    ]

    private final class Recorder {
        var placements: [PremiumPlacement] = []
        var locked: [PremiumFeature] = []
        var performed = 0
    }

    private func makeGate(
        _ entitlement: EntitlementMock,
        recorder: Recorder,
        outcome: PaywallOutcome?,
        waitForEntitlement: @escaping () async -> Void = {}
    ) -> PremiumGate {
        PremiumGate(
            entitlements: entitlement,
            registrar: { placement, onOutcome in
                recorder.placements.append(placement)
                if let outcome { onOutcome(outcome) }
            },
            waitForEntitlement: waitForEntitlement,
            onLocked: { recorder.locked.append($0) }
        )
    }

    @Test(arguments: paidFeatures)
    func placementNotFoundWithoutPlusDoesNotRunAndShowsNotice(feature: PremiumFeature) {
        let recorder = Recorder()
        let gate = makeGate(EntitlementMock(state: .inactive, hasPlus: false), recorder: recorder, outcome: .notPresented)

        gate.gate(feature) { recorder.performed += 1 }

        #expect(recorder.placements.count == 1)
        #expect(recorder.performed == 0)
        #expect(recorder.locked == [feature])
    }

    @Test func everyPaidFeatureMapsToItsPlacement() {
        #expect(Self.paidFeatures.map { PremiumPlacement.request(for: $0).name } == Self.expectedPlacements)
        #expect(Self.paidFeatures.allSatisfy(PremiumAccessRules.requiresPlus(for:)))
    }

    @Test func restoreShowsExactlyOneAlert() {
        // SDK alert covers failures and "no active entitlement"; the app only speaks when the SDK stayed silent.
        #expect(RestoreAlertRules.appMessage(restored: false, sdkHasActiveEntitlement: false, hasPlus: false) == nil)
        #expect(RestoreAlertRules.appMessage(restored: true, sdkHasActiveEntitlement: false, hasPlus: false) == nil)
        #expect(RestoreAlertRules.appMessage(restored: false, sdkHasActiveEntitlement: true, hasPlus: true) == nil)
        #expect(RestoreAlertRules.appMessage(restored: true, sdkHasActiveEntitlement: true, hasPlus: true) == .restored)
        #expect(RestoreAlertRules.appMessage(restored: true, sdkHasActiveEntitlement: true, hasPlus: false) == .nothingFound)
    }

    @Test(arguments: paidFeatures)
    func subscriberRunsWithoutPlacementOrNotice(feature: PremiumFeature) {
        let recorder = Recorder()
        let gate = makeGate(EntitlementMock(state: .active, hasPlus: true), recorder: recorder, outcome: .notPresented)

        gate.gate(feature) { recorder.performed += 1 }

        #expect(recorder.placements.isEmpty)
        #expect(recorder.performed == 1)
        #expect(recorder.locked.isEmpty)
    }

    @Test func paywallClosedWithoutPurchaseNeitherRunsNorShowsNotice() {
        // Non Gated paywalls release the feature on dismissal; without Plus it must stay closed,
        // and the user already saw a paywall, so no extra notice.
        let recorder = Recorder()
        let outcome = PaywallOutcome(paywallPresented: true, purchasedOrRestored: false)
        let gate = makeGate(EntitlementMock(state: .inactive, hasPlus: false), recorder: recorder, outcome: outcome)

        gate.gate(.guidedRosary) { recorder.performed += 1 }

        #expect(recorder.performed == 0)
        #expect(recorder.locked.isEmpty)
    }

    @Test func purchaseRunsFeatureOnceTheEntitlementPropagates() async {
        let recorder = Recorder()
        let entitlement = EntitlementMock(state: .inactive, hasPlus: false)
        let gate = makeGate(entitlement, recorder: recorder, outcome: nil) {
            entitlement.hasPlus = true
            entitlement.entitlementState = .active
        }

        await gate.resolve(
            .verseNarration(isDailyWord: false),
            outcome: PaywallOutcome(paywallPresented: true, purchasedOrRestored: true)
        ) { recorder.performed += 1 }

        #expect(recorder.performed == 1)
        #expect(recorder.locked.isEmpty)
    }

    @Test func purchaseThatNeverActivatesDoesNotRun() async {
        let recorder = Recorder()
        let gate = makeGate(EntitlementMock(state: .inactive, hasPlus: false), recorder: recorder, outcome: nil)

        await gate.resolve(
            .customTimer,
            outcome: PaywallOutcome(paywallPresented: true, purchasedOrRestored: true)
        ) { recorder.performed += 1 }

        #expect(recorder.performed == 0)
        #expect(recorder.locked.isEmpty)
    }

    @Test func dailyWordNarrationStaysFreeWithoutPlacement() {
        let recorder = Recorder()
        let gate = makeGate(EntitlementMock(state: .inactive, hasPlus: false), recorder: recorder, outcome: .notPresented)

        gate.gate(.verseNarration(isDailyWord: true)) { recorder.performed += 1 }

        #expect(recorder.performed == 1)
        #expect(recorder.placements.isEmpty)
        #expect(recorder.locked.isEmpty)
    }

    @Test func verseNarrationStarterHonorsTheGateWhenPlacementIsMissing() {
        let recorder = Recorder()
        let gate = makeGate(EntitlementMock(state: .inactive, hasPlus: false), recorder: recorder, outcome: .notPresented)
        var spoken = 0

        VerseNarrationStarter.start(
            Verse(book: "JHN", chapter: 3, number: 16, text: "Test", language: .pt),
            isDailyWord: false,
            gate: gate
        ) { _ in spoken += 1 }

        #expect(spoken == 0)
        #expect(recorder.locked == [.verseNarration(isDailyWord: false)])
    }

    @Test func plusDeepLinkIsRecognizedWithoutBreakingBibleRoutes() {
        #expect(PlusDeepLink.matches(PlusDeepLink.url))
        #expect(PlusDeepLink.matches(URL(string: "zensounds://plus")!))
        #expect(!PlusDeepLink.matches(URL(string: "zensounds://chapter/PSA/23/1")!))
        #expect(!PlusDeepLink.matches(URL(string: "https://plus")!))
        #expect(BibleDeepLink.parse(PlusDeepLink.url) == nil)
    }

    #if DEBUG
    @Test func debugOverrideForcesOrPassesThroughTheEntitlement() {
        let automatic = DebugPlusOverride.automatic.resolve(state: .unknown, hasPlus: true)
        #expect(automatic.state == .unknown)
        #expect(automatic.hasPlus)
        let subscriber = DebugPlusOverride.subscriber.resolve(state: .inactive, hasPlus: false)
        #expect(subscriber.state == .active)
        #expect(subscriber.hasPlus)
        let nonSubscriber = DebugPlusOverride.nonSubscriber.resolve(state: .active, hasPlus: true)
        #expect(nonSubscriber.state == .inactive)
        #expect(!nonSubscriber.hasPlus)
    }
    #endif
}

struct PlacementCase: Sendable {
    let feature: PremiumFeature
    let parameters: [String: String]
    let expected: PremiumPlacement
}

/// Stable case name: the default description prints dictionaries in random order, which made the
/// runner occasionally report "No result" for the `bible_narration` case.
extension PlacementCase: CustomTestStringConvertible {
    var testDescription: String { expected.name + " " + parameters.keys.sorted().joined(separator: ",") }
}

@MainActor
private final class EntitlementMock: EntitlementProviding {
    var entitlementState: EntitlementState
    var hasPlus: Bool

    init(state: EntitlementState, hasPlus: Bool) {
        entitlementState = state
        self.hasPlus = hasPlus
    }
}
