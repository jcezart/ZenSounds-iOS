import SwiftUI

struct FavoritesView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    private var favoriteSounds: [SoundItem] {
        SoundCatalog.all.filter { preferences.favoriteSoundIds.contains($0.id) }
    }

    var body: some View {
        ZStack {
            palette.background
                .ignoresSafeArea()

            if favoriteSounds.isEmpty && preferences.favoriteVerses.isEmpty {
                FavoritesEmptyState()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        if !preferences.favoriteVerses.isEmpty {
                            FavoritesSection(title: AppLanguage.localized("Verses", defaultValue: "Verses")) {
                                ForEach(preferences.favoriteVerses) { favorite in
                                    FavoriteVerseRow(
                                        favorite: favorite,
                                        onDelete: { remove(favorite) }
                                    )
                                }
                            }
                        }

                        if !favoriteSounds.isEmpty {
                            FavoritesSection(title: AppLanguage.localized("Sounds", defaultValue: "Sounds")) {
                                ForEach(favoriteSounds) { sound in
                                    FavoriteSoundRow(
                                        sound: sound,
                                        onPlay: {
                                            AudioEngine.shared.play(soundId: sound.id)
                                            PlayerPresentation.shared.isFullPlayerPresented = true
                                        },
                                        onDelete: {
                                            preferences.toggleFavoriteSound(sound.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(AppLanguage.localized("Favorites", defaultValue: "Favorites"))
        .navigationDestination(for: Verse.self) { verse in
            VerseDetailView(verse: verse)
        }
    }

    private func remove(_ favorite: FavoriteVerse) {
        preferences.toggleFavoriteVerse(favorite.verse)
    }
}

private struct FavoritesSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.essencePalette) private var palette

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.essenceTitleLarge)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)

            LazyVStack(spacing: 12) {
                content
            }
        }
    }
}

private struct FavoriteSoundRow: View {
    let sound: SoundItem
    let onPlay: () -> Void
    let onDelete: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(sound.id)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            Text(LocalizedStringKey(sound.titleKey))
                .font(.essenceTitleMedium)
                .foregroundStyle(palette.text)

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel("Play sound")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel("Remove from favorites")
        }
        .foregroundStyle(palette.accent)
        .padding(12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FavoriteVerseRow: View {
    let favorite: FavoriteVerse
    let onDelete: () -> Void

    @Environment(\.essencePalette) private var palette

    private var verse: Verse { favorite.verse }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: verse) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reference)
                        .font(.essenceLabelMedium)
                        .foregroundStyle(palette.accent)
                    Text(favorite.text)
                        .font(.essenceBodyMedium)
                        .foregroundStyle(palette.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                ShareLink(item: "\(favorite.text) — \(reference) · ZenSounds") {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Share verse")

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Remove favorite", systemImage: "trash")
                        .font(.essenceLabelMedium)
                }
            }
            .foregroundStyle(palette.accent)
        }
        .padding(16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var reference: String {
        let bookName = BibleCatalog.shared.book(code: favorite.book)?.name(for: favorite.language) ?? favorite.book
        return "\(bookName) \(favorite.chapter):\(favorite.verseNumber)"
    }
}

private struct FavoritesEmptyState: View {
    @Environment(\.essencePalette) private var palette

    var body: some View {
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
    }
}

private extension FavoriteVerse {
    var verse: Verse {
        Verse(
            book: book,
            chapter: chapter,
            number: verseNumber,
            text: text,
            language: language
        )
    }
}
