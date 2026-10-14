import Foundation
import Testing
import UIKit
@testable import ZenSounds

@MainActor
struct UserPreferencesStoreTests {
    private func makeStore() -> (UserPreferencesStore, UserDefaults, String) {
        let suite = "zensounds.preferences.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (UserPreferencesStore(defaults: defaults), defaults, suite)
    }

    @Test func togglesSoundAndVerseFavorites() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let verse = Verse(book: "PSA", chapter: 23, number: 1, text: "Test", language: .en)

        store.toggleFavoriteSound("Rain")
        #expect(store.isFavoriteSound("Rain"))
        store.toggleFavoriteSound("Rain")
        #expect(!store.isFavoriteSound("Rain"))

        store.toggleFavoriteVerse(verse)
        #expect(store.isFavoriteVerse(verse))
        store.toggleFavoriteVerse(verse)
        #expect(!store.isFavoriteVerse(verse))
    }

    @Test func saveMixValidatesNamesAndPreservesIdentityWhenEditing() throws {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let layers = [MixLayer(soundId: "Rain")]

        #expect(store.saveMix(name: "   ", layers: layers) == nil)
        let first = try #require(store.saveMix(name: String(repeating: "A", count: 45), layers: layers))
        #expect(first.name.count == 40)
        #expect(store.saveMix(name: first.name.lowercased(), layers: layers) == nil)

        let edited = try #require(store.saveMix(
            name: "Renamed",
            layers: [MixLayer(soundId: "Storm")],
            existingId: first.id
        ))
        #expect(edited.id == first.id)
        #expect(store.savedMixes.count == 1)
        #expect(store.savedMixes[0].layers.map(\.soundId) == ["Storm"])
    }

    @Test func editingCannotOverwriteAnotherMixByName() throws {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let layers = [MixLayer(soundId: "Rain")]
        let first = try #require(store.saveMix(name: "First", layers: layers))
        _ = try #require(store.saveMix(name: "Second", layers: layers))

        #expect(store.saveMix(name: "Second", layers: layers, existingId: first.id) == nil)
        #expect(store.savedMixes.count == 2)
        #expect(Set(store.savedMixes.map(\.id)).count == 2)
    }

    @Test func removesMixAndPersistsReadingPosition() throws {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let mix = try #require(store.saveMix(name: "Rain", layers: [MixLayer(soundId: "Rain")]))
        store.removeMix(id: mix.id)
        #expect(store.savedMixes.isEmpty)

        store.saveReading(bookCode: "PSA", chapter: 23)
        #expect(store.readingPosition == ReadingPosition(bookCode: "PSA", chapter: 23))
        let restored = UserPreferencesStore(defaults: defaults)
        #expect(restored.readingPosition == store.readingPosition)
    }
}

@MainActor
struct BibleDeepLinkTests {
    @Test func acceptsOnlyCompleteNumericRoutesForKnownBooks() {
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/PSA/23/1")!) == BibleDeepLink(book: "PSA", chapter: 23, verse: 1))
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/PSA/23")!) == nil)
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/PSA/23/1/2")!) == nil)
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/XXX/1/1")!) == nil)
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/PSA/chapter/1")!) == nil)
        #expect(BibleDeepLink.parse(URL(string: "zensounds://chapter/PSA/23/verse")!) == nil)
    }
}

struct BundledResourceIntegrityTests {
    @Test func allBibleBooksAndDeclaredChaptersLoadInBothLanguages() {
        #expect(BibleCatalog.shared.books.count == 66)
        for book in BibleCatalog.shared.books {
            for language in BibleLanguage.allCases {
                for chapter in 1...book.chapters {
                    #expect(!BibleRepository.shared.chapter(bookCode: book.code, number: chapter, language: language).isEmpty)
                }
                #expect(BibleRepository.shared.chapter(bookCode: book.code, number: book.chapters + 1, language: language).isEmpty)
            }
        }
    }

    @Test func everySoundHasAudioAndArtwork() {
        for sound in SoundCatalog.all {
            #expect(Bundle.main.url(forResource: sound.id, withExtension: "mp3") != nil)
            #expect(UIImage(named: sound.id) != nil)
        }
    }

    @Test func everyBiblicalSoundscapePointsToAValidChapter() {
        for soundscape in BiblicalSoundscapeCatalog.all {
            let book = BibleCatalog.shared.book(code: soundscape.bookCode)
            #expect(book != nil)
            #expect(soundscape.chapter > 0 && soundscape.chapter <= (book?.chapters ?? 0))
        }
    }

    @Test func registeredEssenceFontsLoadByPostScriptName() {
        for name in [EssenceFont.regular, EssenceFont.medium, EssenceFont.semibold, EssenceFont.bold] {
            #expect(UIFont(name: name, size: 17) != nil)
        }
    }
}
