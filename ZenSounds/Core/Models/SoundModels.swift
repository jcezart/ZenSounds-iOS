import Foundation

enum SoundCategory: String, CaseIterable, Identifiable, Codable {
    case nature
    case objects
    case vehicles

    var id: String { rawValue }

    /// String Catalog key — see Core/Theme/LocalizedLabels.swift.
    var titleKey: String {
        switch self {
        case .nature: return "category_nature"
        case .objects: return "category_objects"
        case .vehicles: return "category_vehicles"
        }
    }
}

/// A single playable sound. `id` doubles as the audio/artwork resource name
/// (`Resources/Audio/{id}.mp3`, `Assets.xcassets/SoundArt/{id}`).
struct SoundItem: Identifiable, Hashable, Codable {
    let id: String
    let category: SoundCategory
    let defaultVolume: Double

    var titleKey: String {
        switch id {
        case "Rain": return "sound_rain"
        case "Storm": return "sound_storm"
        case "Wind": return "sound_wind"
        case "Forest": return "sound_forest"
        case "Stream": return "sound_stream"
        case "Fireplace": return "sound_fireplace"
        case "TVStatic": return "sound_tv_static"
        case "CarEngine": return "sound_car_engine"
        default: return id
        }
    }
}

/// The 8 real sounds ported from the Android app's `res/raw` + `SoundCatalog.kt`.
/// `TVStatic` keeps its quieter Android default (0.1) — every other sound defaults to full volume.
enum SoundCatalog {
    static let all: [SoundItem] = [
        SoundItem(id: "Rain", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Storm", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Wind", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Forest", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Stream", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Fireplace", category: .objects, defaultVolume: 1.0),
        SoundItem(id: "TVStatic", category: .objects, defaultVolume: 0.1),
        SoundItem(id: "CarEngine", category: .vehicles, defaultVolume: 1.0),
    ]

    static func sound(id: String) -> SoundItem? {
        all.first { $0.id == id }
    }

    static func sounds(in category: SoundCategory) -> [SoundItem] {
        all.filter { $0.category == category }
    }
}
