import Foundation
import Testing
@testable import ZenSounds

@MainActor
struct RecentsTests {
    @Test func repeatsMoveToTheTopAndTheListKeepsTen() {
        var items: [RecentItem] = []
        for chapter in 1...12 {
            items = RecentsRules.adding(.chapter(bookCode: "PSA", chapter: chapter), to: items)
        }
        #expect(items.count == RecentsRules.maxStored)
        #expect(items.first == .chapter(bookCode: "PSA", chapter: 12))
        #expect(!items.contains(.chapter(bookCode: "PSA", chapter: 1)))

        items = RecentsRules.adding(.chapter(bookCode: "PSA", chapter: 5), to: items)
        #expect(items.first == .chapter(bookCode: "PSA", chapter: 5))
        #expect(items.filter { $0 == .chapter(bookCode: "PSA", chapter: 5) }.count == 1)
        #expect(items.count == RecentsRules.maxStored)
    }

    @Test func recentsPersistAndClear() throws {
        let suite = "zensounds.recents.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserPreferencesStore(defaults: defaults)
        #expect(store.recents.isEmpty)
        store.recordRecent(.book(bookCode: "PSA"))
        store.recordRecent(.chapter(bookCode: "LEV", chapter: 5))
        store.recordRecent(.mysteries(.luminous))

        let reloaded = UserPreferencesStore(defaults: defaults)
        #expect(reloaded.recents == [.mysteries(.luminous), .chapter(bookCode: "LEV", chapter: 5), .book(bookCode: "PSA")])

        reloaded.clearRecents()
        #expect(UserPreferencesStore(defaults: defaults).recents.isEmpty)
    }

    @Test func advancingABeadRecordsTheMysteries() throws {
        let suite = "zensounds.recents.rosary.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var recorded: [RecentItem] = []
        let model = RosaryViewModel(progressStore: RosaryProgressStore(defaults: defaults), recordRecent: { recorded.append($0) })
        model.beginNew(set: .glorious)
        #expect(recorded.isEmpty)
        model.next()
        #expect(recorded == [.mysteries(.glorious)])
    }

    @Test func recentTitlesFollowTheMockup() {
        #expect(SearchPresentation.title(for: .chapter(bookCode: "LEV", chapter: 5), language: .pt).hasPrefix("Levítico • "))
        #expect(SearchPresentation.title(for: .book(bookCode: "PSA"), language: .pt) == "Salmos")
        #expect(SearchPresentation.title(for: .mysteries(.luminous), language: .pt) == "Mistérios Luminosos")
    }
}

@MainActor
struct SearchMatchingTests {
    private var books: [BibleBook] { BibleCatalog.shared.books }

    @Test func foldingIgnoresAccentsCaseAndSpaces() {
        #expect(SearchText.fold("  São  JOÃO ") == "sao joao")
        #expect(SearchText.compact("1 Coríntios") == "1corintios")
        #expect(SearchText.words("Salve-Rainha, Mãe!") == "salve rainha mae")
    }

    @Test func booksMatchNamesWithoutAccentsAndAbbreviations() {
        #expect(BookMatcher.matches("genesis", in: books, language: .pt).first?.code == "GEN")
        #expect(BookMatcher.matches("gn", in: books, language: .pt).first?.code == "GEN")
        #expect(BookMatcher.matches("joao", in: books, language: .pt).first?.code == "JHN")
        #expect(BookMatcher.matches("jo", in: books, language: .pt).first?.code == "JHN")
        #expect(BookMatcher.matches("1 cor", in: books, language: .pt).first?.code == "1CO")
        #expect(BookMatcher.matches("1sm", in: books, language: .pt).first?.code == "1SA")
        #expect(BookMatcher.matches("psalms", in: books, language: .pt).first?.code == "PSA")
        #expect(BookMatcher.matches("jn", in: books, language: .en).first?.code == "JHN")
        #expect(BookMatcher.matches("jn", in: books, language: .pt).first?.code == "JON")
        #expect(BookMatcher.matches("xyz", in: books, language: .pt).isEmpty)
    }

    @Test func referencesParseTheUsualForms() {
        #expect(ReferenceParser.parse("jo 3:16", books: books, language: .pt) == [PassageReference(bookCode: "JHN", chapter: 3, verse: 16)])
        #expect(ReferenceParser.parse("Salmo 23", books: books, language: .pt) == [PassageReference(bookCode: "PSA", chapter: 23, verse: nil)])
        #expect(ReferenceParser.parse("gn 1", books: books, language: .pt) == [PassageReference(bookCode: "GEN", chapter: 1, verse: nil)])
        #expect(ReferenceParser.parse("1 jo 4.8", books: books, language: .pt) == [PassageReference(bookCode: "1JN", chapter: 4, verse: 8)])
        #expect(ReferenceParser.parse("john 3:16", books: books, language: .en) == [PassageReference(bookCode: "JHN", chapter: 3, verse: 16)])
        // Out-of-range chapters and plain words are not references.
        #expect(ReferenceParser.parse("gn 51", books: books, language: .pt).isEmpty)
        #expect(ReferenceParser.parse("salmos", books: books, language: .pt).isEmpty)
        #expect(ReferenceParser.parse("23", books: books, language: .pt).isEmpty)
    }

    @Test func rosaryPrayersAndMysteriesAreFound() {
        let repository = RosaryRepository.shared
        #expect(RosarySearch.prayers("salve rainha", in: repository.prayers, language: .pt).map(\.kind) == [.hailHolyQueen])
        #expect(RosarySearch.prayers("ave maria", in: repository.prayers, language: .pt).map(\.kind).contains(.hailMary))
        #expect(RosarySearch.prayers("credo", in: repository.prayers, language: .pt).map(\.kind).contains(.creed))
        #expect(RosarySearch.mysteries("luminosos", in: repository.mysterySets).contains(.init(set: .luminous, mysteryID: nil)))
        #expect(RosarySearch.mysteries("anunciacao", in: repository.mysterySets).contains { $0.set == .joyful && $0.mysteryID != nil })
    }

    @Test func verseTextSearchIsLimitedAndAccentInsensitive() async {
        let codes = books.map(\.code)
        let hits = await VerseSearchIndex.shared.search("coracao partido", language: .pt, bookCodes: codes, limit: 50)
        #expect(!hits.isEmpty)
        #expect(hits.allSatisfy { SearchText.words($0.text).contains("coracao partido") })

        let many = await VerseSearchIndex.shared.search("senhor", language: .pt, bookCodes: codes, limit: VerseSearchRules.resultLimit)
        #expect(many.count == VerseSearchRules.resultLimit)
        #expect(many.first?.bookCode == "GEN")

        #expect(await VerseSearchIndex.shared.search("ab", language: .pt, bookCodes: codes, limit: 50).isEmpty)
    }
}

@MainActor
struct LanguageFollowUpTests {
    @Test func widgetReloadsOnlyWhenTheEffectiveLanguageChanges() {
        #expect(WidgetLanguageSync.needsReload(lastRendered: nil, current: .pt))
        #expect(WidgetLanguageSync.needsReload(lastRendered: .pt, current: .en))
        #expect(!WidgetLanguageSync.needsReload(lastRendered: .en, current: .en))
    }

    @Test func favoritesFollowTheCurrentBibleLanguage() async throws {
        let suite = "zensounds.favorites.language.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserPreferencesStore(defaults: defaults)
        let saved = try #require(BibleRepository.shared.verse(bookCode: "JHN", chapter: 3, number: 16, language: .pt))
        store.toggleFavoriteVerse(saved)
        let favorite = try #require(store.favoriteVerses.first)

        let english = await favorite.verse(in: .en)
        #expect(english.language == .en)
        #expect(english.text == BibleRepository.shared.verse(bookCode: "JHN", chapter: 3, number: 16, language: .en)?.text)
        #expect(english.text != saved.text)

        // Still favorited in the other language, and unfavoriting there removes it.
        #expect(store.isFavoriteVerse(english))
        store.toggleFavoriteVerse(english)
        #expect(store.favoriteVerses.isEmpty)
    }
}

@MainActor
struct InAppLanguageTitleTests {
    /// Runs `body` with the in-app language forced to `language`, restoring the previous choice.
    private func withLanguage(_ language: AppLanguage, _ body: () -> Void) {
        let defaults = AppLanguage.sharedDefaults
        let saved = defaults.string(forKey: AppLanguage.storageKey)
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        defer { defaults.set(saved, forKey: AppLanguage.storageKey) }
        body()
    }

    @Test func playingSoundscapeTitleFollowsTheCurrentLanguage() throws {
        let scape = try #require(BiblicalSoundscapeCatalog.all.first { $0.id == "peace-in-galilee" })
        var mix: SavedMix?
        withLanguage(.pt) {
            // The mix name is frozen in the language it started in…
            mix = scape.playableMix
            #expect(AudioEngine.title(forMix: scape.playableMix) == "Paz na Galileia")
        }
        let started = try #require(mix)
        withLanguage(.en) {
            // …but the title shown follows the language chosen afterwards.
            #expect(AudioEngine.title(forMix: started) == "Peace in Galilee")
            #expect(AudioEngine.title(forMix: SavedMix(id: "mine", name: "Noite", layers: [MixLayer(soundId: "Rain")])) == "Noite")
        }
    }

    @Test func everySoundHasARealTitleInBothLanguages() {
        for sound in SoundCatalog.all {
            withLanguage(.en) {
                #expect(!sound.localizedTitle.contains("_"))
                #expect(sound.localizedTitle.contains(" ") || sound.localizedTitle == sound.id)
            }
            withLanguage(.pt) {
                #expect(sound.localizedTitle != sound.titleKey)
            }
        }
        withLanguage(.en) { #expect(SoundCatalog.sound(id: "GalileeWaves")?.localizedTitle == "Galilee Waves") }
        withLanguage(.pt) { #expect(SoundCatalog.sound(id: "GalileeWaves")?.localizedTitle == "Ondas da Galileia") }
    }

    @Test func codeStyleKeysHaveEnglishText() throws {
        let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let english = try #require(Bundle(path: path))
        let keys = SoundCatalog.all.map(\.titleKey)
            + BiblicalSoundscapeCatalog.all.flatMap { [$0.titleKey, $0.referenceKey] }
        for key in keys {
            #expect(english.localizedString(forKey: key, value: nil, table: nil) != key, "\(key) has no English text")
        }
    }
}
