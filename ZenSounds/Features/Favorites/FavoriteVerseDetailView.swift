import SwiftUI

struct FavoriteVerseDetailView: View {
    let verse: FavoriteVerse

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(reference)
                .font(.essenceTitleMedium)
                .foregroundStyle(palette.accent)
            Text(verse.text)
                .font(.essenceBodyLarge)
                .foregroundStyle(palette.text)
            Spacer()
            HStack {
                ShareLink(item: "\(verse.text) — \(reference)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Spacer()
                Button(role: .destructive) {
                    prefs.toggleFavoriteVerse(Verse(book: verse.book, chapter: verse.chapter, number: verse.verseNumber, text: verse.text, language: verse.language))
                } label: {
                    Label("Remove favorite", systemImage: "heart.slash")
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.background)
        .navigationTitle(reference)
    }

    private var reference: String {
        let bookName = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(bookName) \(verse.chapter):\(verse.verseNumber)"
    }
}
