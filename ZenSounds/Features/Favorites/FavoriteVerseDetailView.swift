import SwiftUI

struct VerseDetailView: View {
    let verse: Verse

    @ObservedObject private var preferences = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    private var isFavorite: Bool {
        preferences.isFavoriteVerse(verse)
    }

    var body: some View {
        ZStack {
            palette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(reference)
                        .font(.essenceTitleMedium)
                        .foregroundStyle(palette.accent)

                    Text(verse.text)
                        .font(.custom(EssenceFont.regular, size: 25, relativeTo: .title2))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            VerseNarrationControls(verse: verse, style: .labeled)
                            shareButton
                            Spacer()
                            favoriteButton
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            VerseNarrationControls(verse: verse, style: .labeled)
                            HStack(spacing: 14) {
                                shareButton
                                favoriteButton
                            }
                        }
                    }
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.accent)
                    .buttonStyle(.bordered)
                }
                .padding(24)
            }
        }
        .navigationTitle(reference)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityAction(named: "Listen to verse") {
            BibleNarrationService.shared.speak(verse)
        }
    }

    private var reference: String {
        let bookName = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(bookName) \(verse.chapter):\(verse.number)"
    }

    private var shareButton: some View {
        ShareLink(item: "\(verse.text) — \(reference) · Orante") {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private var favoriteButton: some View {
        Button {
            preferences.toggleFavoriteVerse(verse)
        } label: {
            Label(
                isFavorite ? "Remove favorite" : "Add favorite",
                systemImage: isFavorite ? "heart.fill" : "heart"
            )
        }
    }
}
