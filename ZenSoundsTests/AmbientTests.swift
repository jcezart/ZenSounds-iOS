import Foundation
import Testing
@testable import ZenSounds

@MainActor
struct AmbientItemTests {
    @Test func mapsWhatTheEngineStartedToARememberableItem() {
        #expect(AmbientItem.from(singleSoundID: "Rain", mixID: nil, savedMixIDs: []) == .sound(id: "Rain"))
        #expect(AmbientItem.from(singleSoundID: nil, mixID: "official.good-shepherd", savedMixIDs: []) == .soundscape(id: "good-shepherd"))
        #expect(AmbientItem.from(singleSoundID: nil, mixID: "my-mix", savedMixIDs: ["my-mix"]) == .mix(id: "my-mix"))
        // Ad-hoc mixes from the editor aren't saved, so they aren't remembered either.
        #expect(AmbientItem.from(singleSoundID: nil, mixID: nil, savedMixIDs: []) == nil)
        #expect(AmbientItem.from(singleSoundID: nil, mixID: "unsaved", savedMixIDs: []) == nil)
    }

    @Test func reusesTheExistingPlacementsAndFreeRules() {
        #expect(AmbientItem.sound(id: "Rain").premiumFeature == .sound(id: "Rain"))
        #expect(!PremiumAccessRules.requiresPlus(for: AmbientItem.fallback.premiumFeature))
        #expect(PremiumPlacement.request(for: AmbientItem.sound(id: "Storm").premiumFeature).name == "premium_sound")
        #expect(PremiumPlacement.request(for: AmbientItem.soundscape(id: "peace-in-galilee").premiumFeature).name == "premium_soundscape")
        #expect(!PremiumAccessRules.requiresPlus(for: AmbientItem.soundscape(id: "good-shepherd").premiumFeature))
        #expect(AmbientItem.mix(id: "x").placementParameters == ["source": "saved_mix"])
        #expect(AmbientItem.soundscape(id: "garden-prayer").placementParameters == ["soundscape_id": "garden-prayer"])
    }

    @Test func miniPlayerVisibilityFollowsTheScreenRule() {
        #expect(AmbientMiniPlayerVisibility.always.isVisible(isAudioActive: false))
        #expect(AmbientMiniPlayerVisibility.always.isVisible(isAudioActive: true))
        #expect(!AmbientMiniPlayerVisibility.whenActive.isVisible(isAudioActive: false))
        #expect(AmbientMiniPlayerVisibility.whenActive.isVisible(isAudioActive: true))
    }

    @Test func lastAmbientPersistsAndFallsBackWhenTheMixIsGone() throws {
        let suite = "zensounds.ambient.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserPreferencesStore(defaults: defaults)
        #expect(store.resolvedLastAmbient == .fallback)

        store.recordAmbient(.soundscape(id: "peace-in-galilee"))
        #expect(UserPreferencesStore(defaults: defaults).resolvedLastAmbient == .soundscape(id: "peace-in-galilee"))

        let mix = try #require(store.saveMix(name: "Noite", layers: [MixLayer(soundId: "Rain")]))
        store.recordAmbient(.mix(id: mix.id))
        #expect(store.resolvedLastAmbient == .mix(id: mix.id))
        store.removeMix(id: mix.id)
        #expect(store.resolvedLastAmbient == .fallback)
    }

    @Test func everySoundHasASymbol() {
        for sound in SoundCatalog.all {
            #expect(!AmbientSoundSymbol.name(forSoundID: sound.id).isEmpty)
        }
    }
}
