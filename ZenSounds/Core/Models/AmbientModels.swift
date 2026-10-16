import Foundation

/// What the "Ambient sound" mini-player remembers and can start again: a single sound, an official
/// Biblical Soundscape or a saved mix. Persisted as the last thing played (ad-hoc mixes aren't kept).
enum AmbientItem: Codable, Equatable, Hashable, Sendable {
    case sound(id: String)
    case soundscape(id: String)
    case mix(id: String)

    /// Shown before anything was ever played: Rain, one of the free sounds.
    static let fallback = AmbientItem.sound(id: "Rain")

    /// Maps what `AudioEngine` just started to the item worth remembering.
    static func from(singleSoundID: String?, mixID: String?, savedMixIDs: Set<String>) -> AmbientItem? {
        if let singleSoundID { return .sound(id: singleSoundID) }
        guard let mixID else { return nil }
        if let soundscape = BiblicalSoundscapeCatalog.soundscape(forMixID: mixID) {
            return .soundscape(id: soundscape.id)
        }
        return savedMixIDs.contains(mixID) ? .mix(id: mixID) : nil
    }

    /// The premium feature gating a fresh start of this item.
    var premiumFeature: PremiumFeature {
        switch self {
        case .sound(let id): .sound(id: id)
        case .soundscape(let id): .soundscape(id: id)
        case .mix: .savedMix
        }
    }

    var placementParameters: [String: String] {
        switch self {
        case .sound(let id): ["sound_id": id]
        case .soundscape(let id): ["soundscape_id": id]
        case .mix: ["source": "saved_mix"]
        }
    }
}

/// Where the mini-player is drawn. Reading and Rosary always show it (so the ambient sound is one tap
/// away), lists only while something is playing. Today shows it inline at the end of its content.
nonisolated enum AmbientMiniPlayerVisibility: Sendable {
    case always
    case whenActive

    func isVisible(isAudioActive: Bool) -> Bool {
        switch self {
        case .always: true
        case .whenActive: isAudioActive
        }
    }
}

enum AmbientSoundSymbol {
    /// SF Symbol for the mini-player and sheet rows.
    static func name(forSoundID id: String) -> String {
        switch id {
        case "Rain": "cloud.rain"
        case "Storm": "cloud.bolt.rain"
        case "Wind": "wind"
        case "Forest": "tree"
        case "Stream", "GalileeWaves": "water.waves"
        case "Fireplace": "flame"
        case "MorningBirds": "bird"
        case "NightCrickets": "moon.stars"
        case "OliveGrove", "MeadowSheep": "leaf"
        default: "waveform"
        }
    }
}
