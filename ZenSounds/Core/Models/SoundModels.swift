import Foundation

enum SoundCategory: String, CaseIterable, Identifiable, Codable {
    case nature
    case objects

    var id: String { rawValue }

    /// String Catalog key resolved by `AppLanguage.localized`.
    var titleKey: String {
        switch self {
        case .nature: return "category_nature"
        case .objects: return "category_objects"
        }
    }

    var defaultTitle: String {
        switch self {
        case .nature: return "Nature Sounds"
        case .objects: return "Object Sounds"
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
        case "GalileeWaves": return "sound_galilee_waves"
        case "MeadowSheep": return "sound_meadow_sheep"
        case "OliveGrove": return "sound_olive_grove"
        case "MorningBirds": return "sound_morning_birds"
        case "NightCrickets": return "sound_night_crickets"
        default: return id
        }
    }
}

/// The bundled relaxation sounds available throughout the app.
enum SoundCatalog {
    static let all: [SoundItem] = [
        SoundItem(id: "Rain", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Storm", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Wind", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Forest", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Stream", category: .nature, defaultVolume: 1.0),
        SoundItem(id: "Fireplace", category: .objects, defaultVolume: 1.0),
        SoundItem(id: "GalileeWaves", category: .nature, defaultVolume: 0.82),
        SoundItem(id: "MeadowSheep", category: .nature, defaultVolume: 0.42),
        SoundItem(id: "OliveGrove", category: .nature, defaultVolume: 0.72),
        SoundItem(id: "MorningBirds", category: .nature, defaultVolume: 0.52),
        SoundItem(id: "NightCrickets", category: .nature, defaultVolume: 0.45),
    ]

    static func sound(id: String) -> SoundItem? {
        all.first { $0.id == id }
    }

    static func sounds(in category: SoundCategory) -> [SoundItem] {
        all.filter { $0.category == category }
    }
}

struct BiblicalSoundscape: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let defaultTitle: String
    let referenceKey: String
    let defaultReference: String
    let bookCode: String
    let chapter: Int
    let artworkName: String
    let symbolName: String
    let layers: [MixLayer]

    var localizedTitle: String {
        AppLanguage.localized(titleKey, defaultValue: defaultTitle)
    }

    var localizedReference: String {
        AppLanguage.localized(referenceKey, defaultValue: defaultReference)
    }

    var playableMix: SavedMix {
        SavedMix(id: officialMixID, name: localizedTitle, layers: layers)
    }

    var officialMixID: String { "official.\(id)" }
}

enum BiblicalSoundscapeCatalog {
    static let all: [BiblicalSoundscape] = [
        BiblicalSoundscape(
            id: "good-shepherd",
            titleKey: "soundscape_good_shepherd",
            defaultTitle: "The Good Shepherd",
            referenceKey: "reference_psalm_23",
            defaultReference: "Psalm 23",
            bookCode: "PSA",
            chapter: 23,
            artworkName: "MeadowSheep",
            symbolName: "figure.walk",
            layers: [
                MixLayer(soundId: "Stream", volume: 0.55),
                MixLayer(soundId: "MeadowSheep", volume: 0.22),
                MixLayer(soundId: "Wind", volume: 0.23),
            ]
        ),
        BiblicalSoundscape(
            id: "peace-in-galilee",
            titleKey: "soundscape_peace_galilee",
            defaultTitle: "Peace in Galilee",
            referenceKey: "reference_mark_4_39",
            defaultReference: "Mark 4:39",
            bookCode: "MRK",
            chapter: 4,
            artworkName: "GalileeWaves",
            symbolName: "water.waves",
            layers: [
                MixLayer(soundId: "GalileeWaves", volume: 0.60),
                MixLayer(soundId: "Wind", volume: 0.18),
                MixLayer(soundId: "MorningBirds", volume: 0.22),
            ]
        ),
        BiblicalSoundscape(
            id: "garden-prayer",
            titleKey: "soundscape_garden_prayer",
            defaultTitle: "Prayer in the Garden",
            referenceKey: "reference_matthew_26_36",
            defaultReference: "Matthew 26:36",
            bookCode: "MAT",
            chapter: 26,
            artworkName: "OliveGrove",
            symbolName: "leaf.fill",
            layers: [
                MixLayer(soundId: "OliveGrove", volume: 0.68),
                MixLayer(soundId: "Wind", volume: 0.20),
                MixLayer(soundId: "MorningBirds", volume: 0.12),
            ]
        ),
        BiblicalSoundscape(
            id: "night-in-bethlehem",
            titleKey: "soundscape_bethlehem_night",
            defaultTitle: "A Night in Bethlehem",
            referenceKey: "reference_luke_2_8",
            defaultReference: "Luke 2:8",
            bookCode: "LUK",
            chapter: 2,
            artworkName: "NightCrickets",
            symbolName: "moon.stars.fill",
            layers: [
                MixLayer(soundId: "NightCrickets", volume: 0.55),
                MixLayer(soundId: "Wind", volume: 0.25),
                MixLayer(soundId: "MeadowSheep", volume: 0.20),
            ]
        ),
    ]

    static func soundscape(forMixID mixID: String?) -> BiblicalSoundscape? {
        guard let mixID else { return nil }
        return all.first { $0.officialMixID == mixID }
    }
}
