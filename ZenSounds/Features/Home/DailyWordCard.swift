import SwiftUI

struct DailyWordCard: View {
    let state: DailyWordViewModel.State
    let onShuffle: () -> Void
    let onExplore: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WORD OF THE DAY")
                .font(.essenceLabelMedium)
                .foregroundStyle(palette.onVerse.opacity(0.8))

            if let verse = state.verse {
                Text(verse.text)
                    .font(.essenceBodyLarge)
                    .foregroundStyle(palette.onVerse)
                    .fixedSize(horizontal: false, vertical: true)
                Text(reference(verse))
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.onVerse.opacity(0.85))
            } else if state.isLoading {
                ProgressView().tint(palette.onVerse)
            } else {
                Text("No verse available offline.")
                    .foregroundStyle(palette.onVerse)
            }

            HStack {
                Button(action: onExplore) {
                    Label(exploreLabel, systemImage: "book")
                        .font(.essenceLabelLarge)
                        .foregroundStyle(palette.onVerse)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                Button(action: onShuffle) {
                    Image(systemName: "shuffle")
                        .foregroundStyle(palette.onVerse)
                        .padding(10)
                        .background(Color.black.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Show another verse")
            }
        }
        .padding(20)
        .background(palette.verseBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func reference(_ verse: Verse) -> String {
        let bookName = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(bookName) \(verse.chapter):\(verse.number)"
    }

    private var exploreLabel: String {
        guard let reading = state.reading, let book = BibleCatalog.shared.book(code: reading.book) else {
            return NSLocalizedString("Explore", comment: "Fallback label when no daily reading is available yet")
        }
        let language = state.verse?.language ?? .en
        let format = NSLocalizedString("Explore %@", comment: "Explore <book name>, opens that book's chapter")
        return String(format: format, book.name(for: language))
    }
}
