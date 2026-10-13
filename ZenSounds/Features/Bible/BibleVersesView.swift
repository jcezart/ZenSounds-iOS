import SwiftUI

struct BibleVersesView: View {
    let bookCode: String
    let chapter: Int
    let language: BibleLanguage
    var focusVerse: Int? = nil

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @ObservedObject private var narration = BibleNarrationService.shared
    @Environment(\.essencePalette) private var palette
    @State private var verses: [Verse] = []
    @State private var isLoading = true

    private var book: BibleBook? { BibleCatalog.shared.book(code: bookCode) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    ProgressView().padding(.top, 60)
                } else if verses.isEmpty {
                    ContentUnavailableView("Chapter unavailable", systemImage: "book.closed")
                        .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(verses) { verse in
                            VerseRow(verse: verse, isFavorite: prefs.isFavoriteVerse(verse)) {
                                prefs.toggleFavoriteVerse(verse)
                            }
                            .id(verse.number)
                            .padding(8)
                            .background(
                                rowBackground(for: verse),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay {
                                if narration.isCurrent(verse) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(palette.accent.opacity(0.7), lineWidth: 1.5)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .task(id: "\(bookCode):\(chapter):\(language.rawValue)") {
                await load()
                if let focusVerse {
                    await Task.yield()
                    withAnimation { proxy.scrollTo(focusVerse, anchor: .center) }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .background(palette.background)
        .navigationDestination(for: Verse.self) { verse in
            VerseDetailView(verse: verse)
        }
    }

    private var navigationTitle: String {
        guard let book else { return bookCode }
        return "\(book.name(for: language)) \(chapter)"
    }

    private func rowBackground(for verse: Verse) -> Color {
        if narration.isCurrent(verse) {
            return palette.lilac.opacity(0.82)
        }
        return focusVerse == verse.number ? palette.lilac.opacity(0.6) : .clear
    }

    private func load() async {
        isLoading = true
        verses = await BibleRepository.shared.chapterAsync(
            bookCode: bookCode,
            number: chapter,
            language: language
        )
        isLoading = false
        if !verses.isEmpty {
            prefs.saveReading(bookCode: bookCode, chapter: chapter)
        }
    }
}

struct VerseRow: View {
    let verse: Verse
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(value: verse) {
                HStack(alignment: .top, spacing: 4) {
                    Text("\(verse.number)")
                        .font(.essenceLabelMedium)
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 24, alignment: .trailing)
                    Text(verse.text)
                        .font(.essenceBodyLarge)
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                VerseNarrationControls(verse: verse)
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(palette.accent)
                }
                .accessibilityLabel(isFavorite ? "Remove verse from favorites" : "Add verse to favorites")
                ShareLink(item: "\(verse.text) — \(verse.book) \(verse.chapter):\(verse.number)") {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(palette.secondaryText)
                }
                .accessibilityLabel("Share verse")
            }
        }
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            BibleVersesView(bookCode: "PSA", chapter: 23, language: .pt)
        }
    }
}
