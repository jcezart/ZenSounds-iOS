import SwiftUI

struct DailyWordCard: View {
    let state: DailyWordViewModel.State
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onShuffle: () -> Void
    let onExplore: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(palette.onVerse.opacity(0.07))
                .frame(width: 210, height: 210)
                .offset(x: 78, y: 65)
                .accessibilityHidden(true)

            BotanicalArtwork(color: Color.black.opacity(0.22))
                .frame(width: 104, height: 230)
                .offset(x: 14, y: 16)

            VStack(alignment: .leading, spacing: 16) {
                Text(header)
                    .font(.essenceLabelMedium)
                    .tracking(1.2)
                    .foregroundStyle(palette.onVerse.opacity(0.88))

                Group {
                    if let verse = state.verse {
                        Text(verse.text)
                            .font(.custom(EssenceFont.regular, size: 24, relativeTo: .title2))
                            .foregroundStyle(palette.onVerse)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if state.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(palette.onVerse)
                            Spacer()
                        }
                        .frame(minHeight: 112)
                    } else {
                        Text("No verse available offline.")
                            .font(.essenceBodyLarge)
                            .foregroundStyle(palette.onVerse)
                            .frame(minHeight: 112, alignment: .topLeading)
                    }
                }

                HStack(spacing: 6) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(state.verse == nil)
                    .accessibilityLabel(isFavorite ? "Remove verse from favorites" : "Add verse to favorites")

                    if let verse = state.verse {
                        ShareLink(item: "\(verse.text) — \(reference(verse)) · Orante") {
                            Image(systemName: "square.and.arrow.up")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Share verse")
                    }

                    Button(action: onShuffle) {
                        Image(systemName: "shuffle")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(state.isLoading)
                    .accessibilityLabel("Show another verse")

                    if let verse = state.verse {
                        VerseNarrationControls(verse: verse, isDailyWord: true, tint: palette.onVerse)
                    }

                    Spacer()

                    Button(action: onExplore) {
                        HStack(spacing: 9) {
                            Text("Open chapter")
                                .font(.essenceLabelMedium)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(palette.onVerse, in: Circle())
                                .foregroundStyle(palette.verseBackground)
                        }
                    }
                    .disabled(state.verse == nil)
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(palette.onVerse)
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(palette.verseBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var header: String {
        guard let verse = state.verse else {
            return AppLanguage.localized("WORD OF THE DAY", defaultValue: "WORD OF THE DAY")
        }
        return AppLanguage.localized("TODAY", defaultValue: "TODAY") + " · " + reference(verse)
    }

    private func reference(_ verse: Verse) -> String {
        let bookName = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(bookName) \(verse.chapter):\(verse.number)"
    }
}
