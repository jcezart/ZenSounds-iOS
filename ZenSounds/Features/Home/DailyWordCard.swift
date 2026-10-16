import SwiftUI

struct DailyWordCard: View {
    /// Re-renders titles resolved with `AppLanguage.localized` when the in-app language changes.
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let state: DailyWordViewModel.State
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onShuffle: () -> Void
    let onExplore: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("DailyWordLeaf")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(palette.onVerse.opacity(0.13))
                .frame(width: 132, height: 212)
                .offset(x: 18, y: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(header)
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.onVerse.opacity(0.88))

                Group {
                    if let verse = state.verse {
                        Text(verse.text)
                            .font(.scriptureHeadline)
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
                        // The narration controls (play/pause + stop) must never squeeze this label: show the
                        // text only when it fits on one line, otherwise just the arrow.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 9) {
                                Text("Open chapter")
                                    .font(.essenceLabelMedium)
                                    .lineLimit(1)
                                    .fixedSize()
                                openChapterArrow
                            }
                            openChapterArrow
                        }
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    }
                    .disabled(state.verse == nil)
                    .accessibilityLabel("Open chapter")
                    .layoutPriority(1)
                }
                .font(.body.weight(.medium))
                .foregroundStyle(palette.onVerse)
                .buttonStyle(.plain)
            }
            .padding(Spacing.lg)
        }
        .background(palette.verseBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var openChapterArrow: some View {
        Image(systemName: "arrow.right")
            .font(.footnote.weight(.semibold))
            .frame(minWidth: 34, minHeight: 34)
            .background(palette.onVerse, in: Circle())
            .foregroundStyle(palette.verseBackground)
    }

    private var header: String {
        guard let verse = state.verse else {
            return AppLanguage.localized("WORD OF THE DAY", defaultValue: "WORD OF THE DAY")
        }
        return reference(verse)
    }

    private func reference(_ verse: Verse) -> String {
        let bookName = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(bookName) \(verse.chapter):\(verse.number)"
    }
}

#if DEBUG
private let previewState = DailyWordViewModel.State(
    reading: DailyReadingRef(book: "PSA", chapter: 34, verse: 18),
    verse: Verse(book: "PSA", chapter: 34, number: 18, text: "O SENHOR está perto daqueles que estão com o coração partido.", language: .pt),
    isLoading: false
)

private struct DailyWordCardPreview: View {
    let width: CGFloat

    var body: some View {
        DailyWordCard(state: previewState, isFavorite: false, onToggleFavorite: {}, onShuffle: {}, onExplore: {})
            .frame(width: width)
            .padding()
    }
}

// Card widths: iPhone SE 335 pt, Pro Max 400 pt. The narration pause + stop controls take ~52 pt more,
// so 283 pt reproduces the SE row while narration is active.
#Preview("SE") { ZenSoundsTheme { DailyWordCardPreview(width: 335) } }
#Preview("SE narrating") { ZenSoundsTheme { DailyWordCardPreview(width: 283) } }
#Preview("Pro Max") { ZenSoundsTheme { DailyWordCardPreview(width: 400) } }
#Preview("SE AX3") {
    ZenSoundsTheme { DailyWordCardPreview(width: 335) }
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
