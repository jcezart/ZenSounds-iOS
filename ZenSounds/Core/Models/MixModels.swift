import Foundation

struct MixLayer: Identifiable, Hashable, Codable {
    var soundId: String
    var volume: Double

    var id: String { soundId }

    init(soundId: String, volume: Double = 0.6) {
        self.soundId = soundId
        self.volume = volume
    }
}

struct SavedMix: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var layers: [MixLayer]
}

/// Mirrors the Android app's `data/PlaybackModels.kt::MixRules`.
enum MixRules {
    static let maxLayers = 8

    static func normalize(_ layers: [MixLayer]) -> [MixLayer] {
        var seen = Set<String>()
        var result: [MixLayer] = []
        for layer in layers {
            guard SoundCatalog.sound(id: layer.soundId) != nil, layer.volume.isFinite else { continue }
            guard !seen.contains(layer.soundId) else { continue }
            seen.insert(layer.soundId)
            result.append(MixLayer(soundId: layer.soundId, volume: min(max(layer.volume, 0), 1)))
            if result.count == maxLayers { break }
        }
        return result
    }

    /// Final per-layer gain: each layer's proportional share of the combined layer volume,
    /// scaled by the master volume and the timer fade multiplier — so a mix with many layers
    /// never plays louder overall than a single sound at full volume.
    static func gains(layers: [MixLayer], master: Double, fade: Double) -> [String: Double] {
        let total = layers.reduce(0) { $0 + $1.volume }
        guard total > 0 else { return [:] }
        return layers.reduce(into: [String: Double]()) { result, layer in
            result[layer.soundId] = (layer.volume / total) * master * fade
        }
    }
}
