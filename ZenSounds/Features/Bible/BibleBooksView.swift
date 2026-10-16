import SwiftUI

/// Bible tab root: hero with Psalm 119:105, "Continue reading", Old/New Testament switch and the book list.
struct BibleBooksView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @EnvironmentObject private var navigation: NavigationModel
    @Environment(\.essencePalette) private var palette

    @State private var testament: BibleTestament = .old
    @State private var heroVerse: Verse?

    private var language: BibleLanguage { languageStore.selection.bibleLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                hero
                continueCard

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Picker(selection: $testament) {
                        Text("Old Testament").tag(BibleTestament.old)
                        Text("New Testament").tag(BibleTestament.new)
                    } label: {
                        Text(verbatim: "")
                    }
                    .pickerStyle(.segmented)

                    bookList
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .navigationTitle(AppLanguage.localized("Bible", defaultValue: "Bible"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: BibleRoute.self) { route in
            BibleRouteDestination(route: route, language: language)
        }
        .task(id: language) {
            heroVerse = await BibleRepository.shared.verseAsync(bookCode: "PSA", chapter: 119, number: 105, language: language)
        }
        .ambientMiniPlayer(.whenActive)
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .trailing) {
            Image("BibleHero")
                .resizable()
                .scaledToFill()
                .frame(height: 176)
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityHidden(true)
            // Keeps the verse legible over the artwork.
            LinearGradient(
                colors: [.clear, .black.opacity(0.25), .black.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
            if let heroVerse {
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(Self.heroText(heroVerse.text))
                        .font(.scriptureCaption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.75)
                    Text(reference(for: heroVerse))
                        .font(.essenceLabelMedium)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: 210, alignment: .trailing)
                .padding(Spacing.md)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(minHeight: 176)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    // MARK: Continue

    private var continueCard: some View {
        let position = preferences.readingPosition ?? ReadingPosition(bookCode: "GEN", chapter: 1)
        let name = BibleCatalog.shared.book(code: position.bookCode)?.name(for: language) ?? position.bookCode
        return ShortcutRow(
            systemImage: "book.pages",
            title: preferences.readingPosition == nil ? Text("Start reading") : Text("Continue reading"),
            subtitle: "\(name) · \(AppLanguage.localized("Chapter", defaultValue: "Chapter")) \(position.chapter)"
        ) {
            navigation.biblePath.append(BibleRoute.verses(bookCode: position.bookCode, chapter: position.chapter, focusVerse: nil))
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    // MARK: Books

    private var bookList: some View {
        let books = testament.books(from: BibleCatalog.shared.books)
        return LazyVStack(spacing: 0) {
            ForEach(books) { book in
                NavigationLink(value: BibleRoute.chapters(bookCode: book.code)) {
                    BookRow(name: book.name(for: language), chapters: book.chapters)
                }
                .buttonStyle(.plain)
                if book.id != books.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    /// The Bíblia Livre prefixes the stanza's Hebrew letter ("Nun :") to Psalm 119:105; the hero quote
    /// drops that label for display only (the reader keeps the source text untouched).
    static func heroText(_ text: String) -> String {
        text.replacing(/^\p{L}+\s*:\s*/, with: "")
    }

    private func reference(for verse: Verse) -> String {
        let name = BibleCatalog.shared.book(code: verse.book)?.name(for: verse.language) ?? verse.book
        return "\(name) \(verse.chapter):\(verse.number)"
    }
}

private struct BookRow: View {
    let name: String
    let chapters: Int
    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "book.closed")
                .font(.body)
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.essenceTitleMedium)
                    .foregroundStyle(palette.text)
                Text("\(chapters) chapters")
                    .font(.essenceBodySmall)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: Spacing.xs)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct BibleRouteDestination: View {
    let route: BibleRoute
    let language: BibleLanguage

    var body: some View {
        switch route {
        case .chapters(let bookCode):
            BibleChaptersView(bookCode: bookCode, language: language)
        case .verses(let bookCode, let chapter, let focusVerse):
            BibleVersesView(bookCode: bookCode, chapter: chapter, language: language, focusVerse: focusVerse)
        }
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            BibleBooksView()
        }
        .environmentObject(NavigationModel())
    }
}

#Preview("Dark") {
    ZenSoundsTheme {
        NavigationStack {
            BibleBooksView()
        }
        .environmentObject(NavigationModel())
    }
    .preferredColorScheme(.dark)
}
