import SwiftUI

struct FavoritesView: View {
    @ObservedObject private var prefs = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    private var favoriteSounds: [SoundItem] {
        SoundCatalog.all.filter { prefs.favoriteSoundIds.contains($0.id) }
    }

    var body: some View {
        Group {
            if favoriteSounds.isEmpty && prefs.favoriteVerses.isEmpty {
                emptyState
            } else {
                List {
                    if !favoriteSounds.isEmpty {
                        Section("Sounds") {
                            ForEach(favoriteSounds) { sound in
                                Button {
                                    AudioEngine.shared.play(soundId: sound.id)
                                    PlayerPresentation.shared.isFullPlayerPresented = true
                                } label: {
                                    HStack {
                                        Text(NSLocalizedString(sound.titleKey, value: sound.id, comment: ""))
                                            .foregroundStyle(palette.text)
                                        Spacer()
                                        Image(systemName: "play.circle").foregroundStyle(palette.accent)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet { prefs.toggleFavoriteSound(favoriteSounds[index].id) }
                            }
                        }
                    }
                    if !prefs.favoriteVerses.isEmpty {
                        Section("Verses") {
                            ForEach(prefs.favoriteVerses) { verse in
                                NavigationLink(value: verse) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(verse.text).font(.essenceBodyMedium).foregroundStyle(palette.text).lineLimit(2)
                                        Text(reference(verse)).font(.essenceBodySmall).foregroundStyle(palette.secondaryText)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let v = prefs.favoriteVerses[index]
                                    prefs.toggleFavoriteVerse(Verse(book: v.book, chapter: v.chapter, number: v.verseNumber, text: v.text, language: v.language))
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationDestination(for: FavoriteVerse.self) { verse in
            FavoriteVerseDetailView(verse: verse)
        }
        .background(palette.background)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundStyle(palette.secondaryText)
                .accessibilityHidden(true)
            Text("No favorites yet")
                .font(.essenceTitleMedium)
                .foregroundStyle(palette.text)
            Text("Tap the heart on a sound or verse to save it here.")
                .font(.essenceBodyMedium)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    private func reference(_ verse: FavoriteVerse) -> String {
        let bookName = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(bookName) \(verse.chapter):\(verse.verseNumber)"
    }
}
