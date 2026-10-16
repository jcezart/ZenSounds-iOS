import SwiftUI

/// Starting and describing ambient items. Every fresh start goes through the premium gate with the
/// existing placements (`premium_sound`, `premium_soundscape`, `create_mix` + `source: saved_mix`).
enum AmbientPlayback {
    static func start(_ item: AmbientItem) {
        let audio = AudioEngine.shared
        let gate = SuperwallService.shared
        switch item {
        case .sound(let id):
            gate.gate(item.premiumFeature, parameters: item.placementParameters) {
                audio.play(soundId: id)
            }
        case .soundscape(let id):
            guard let soundscape = BiblicalSoundscapeCatalog.all.first(where: { $0.id == id }) else { return }
            gate.gate(item.premiumFeature, parameters: item.placementParameters) {
                audio.playMix(soundscape.playableMix)
            }
        case .mix(let id):
            guard let mix = UserPreferencesStore.shared.savedMixes.first(where: { $0.id == id }) else { return }
            gate.gate(item.premiumFeature, parameters: item.placementParameters) {
                audio.playMix(mix)
            }
        }
    }

    /// The item currently playing, if it maps to something rememberable.
    static func currentItem() -> AmbientItem? {
        let audio = AudioEngine.shared
        return AmbientItem.from(
            singleSoundID: audio.activeSoundId,
            mixID: audio.activeMix?.id,
            savedMixIDs: Set(UserPreferencesStore.shared.savedMixes.map(\.id))
        )
    }

    static func title(for item: AmbientItem) -> String {
        switch item {
        case .sound(let id):
            guard let sound = SoundCatalog.sound(id: id) else { return id }
            return AppLanguage.localized(sound.titleKey, defaultValue: id)
        case .soundscape(let id):
            return BiblicalSoundscapeCatalog.all.first { $0.id == id }?.localizedTitle ?? id
        case .mix(let id):
            return UserPreferencesStore.shared.savedMixes.first { $0.id == id }?.name ?? id
        }
    }

    static func symbol(for item: AmbientItem) -> String {
        switch item {
        case .sound(let id): AmbientSoundSymbol.name(forSoundID: id)
        case .soundscape(let id): BiblicalSoundscapeCatalog.all.first { $0.id == id }?.symbolName ?? "waveform"
        case .mix: "slider.horizontal.3"
        }
    }
}
