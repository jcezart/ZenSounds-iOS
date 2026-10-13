import Foundation
import Combine

struct FavoriteVerse: Identifiable, Hashable, Codable {
    let book: String
    let chapter: Int
    let verseNumber: Int
    let text: String
    let language: BibleLanguage

    var id: String { "\(language.rawValue):\(book):\(chapter):\(verseNumber)" }
}

struct ReadingPosition: Equatable, Codable {
    let bookCode: String
    let chapter: Int
}

/// Favorites (sounds + verses) and saved mixes, persisted locally. Mirrors the Android app's
/// `data/EssencePreferences.kt` (SharedPreferences-backed, exposed reactively) — same shape,
/// `UserDefaults` + JSON instead of SharedPreferences.
@MainActor
final class UserPreferencesStore: ObservableObject {
    static let shared = UserPreferencesStore()

    @Published private(set) var favoriteSoundIds: Set<String>
    @Published private(set) var favoriteVerses: [FavoriteVerse]
    @Published private(set) var savedMixes: [SavedMix]
    @Published private(set) var readingPosition: ReadingPosition?

    private let defaults = UserDefaults.standard
    private let soundsKey = "zensounds.favorite_sounds"
    private let versesKey = "zensounds.favorite_verses"
    private let mixesKey = "zensounds.saved_mixes"
    private let readingPositionKey = "zensounds.reading_position"

    private init() {
        favoriteSoundIds = Set(defaults.stringArray(forKey: soundsKey) ?? [])
        favoriteVerses = Self.decode([FavoriteVerse].self, defaults.data(forKey: versesKey)) ?? []
        savedMixes = Self.decode([SavedMix].self, defaults.data(forKey: mixesKey)) ?? []
        readingPosition = Self.decode(ReadingPosition.self, defaults.data(forKey: readingPositionKey))
    }

    func isFavoriteSound(_ id: String) -> Bool {
        favoriteSoundIds.contains(id)
    }

    func toggleFavoriteSound(_ id: String) {
        if favoriteSoundIds.contains(id) {
            favoriteSoundIds.remove(id)
        } else {
            favoriteSoundIds.insert(id)
        }
        defaults.set(Array(favoriteSoundIds), forKey: soundsKey)
    }

    func isFavoriteVerse(_ verse: Verse) -> Bool {
        favoriteVerses.contains { $0.matches(verse) }
    }

    func toggleFavoriteVerse(_ verse: Verse) {
        if let index = favoriteVerses.firstIndex(where: { $0.matches(verse) }) {
            favoriteVerses.remove(at: index)
        } else {
            favoriteVerses.insert(
                FavoriteVerse(book: verse.book, chapter: verse.chapter, verseNumber: verse.number, text: verse.text, language: verse.language),
                at: 0
            )
        }
        defaults.set(Self.encode(favoriteVerses), forKey: versesKey)
    }

    /// Saves (or, if a mix with the same name already exists, overwrites) a named combination.
    @discardableResult
    func saveMix(name: String, layers: [MixLayer], existingId: String? = nil) -> SavedMix? {
        let normalized = MixRules.normalize(layers)
        let trimmedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmedName.isEmpty, !normalized.isEmpty else { return nil }

        let mix: SavedMix
        if let matchIndex = savedMixes.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            mix = SavedMix(id: savedMixes[matchIndex].id, name: trimmedName, layers: normalized)
            savedMixes[matchIndex] = mix
        } else {
            mix = SavedMix(id: existingId ?? UUID().uuidString, name: trimmedName, layers: normalized)
            savedMixes.insert(mix, at: 0)
        }
        defaults.set(Self.encode(savedMixes), forKey: mixesKey)
        return mix
    }

    func removeMix(id: String) {
        savedMixes.removeAll { $0.id == id }
        defaults.set(Self.encode(savedMixes), forKey: mixesKey)
    }

    func saveReading(bookCode: String, chapter: Int) {
        let position = ReadingPosition(bookCode: bookCode, chapter: chapter)
        guard position != readingPosition else { return }
        readingPosition = position
        defaults.set(Self.encode(position), forKey: readingPositionKey)
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? { try? JSONEncoder().encode(value) }
    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

private extension FavoriteVerse {
    func matches(_ verse: Verse) -> Bool {
        book == verse.book && chapter == verse.chapter && verseNumber == verse.number && language == verse.language
    }
}
