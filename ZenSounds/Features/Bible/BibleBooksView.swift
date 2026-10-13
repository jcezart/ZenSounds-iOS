import SwiftUI

struct BibleBooksView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.essencePalette) private var palette

    private var language: BibleLanguage { languageStore.selection.bibleLanguage }
    private var books: [BibleBook] { BibleCatalog.shared.books }

    var body: some View {
        List(books) { book in
            NavigationLink(value: BibleRoute.chapters(bookCode: book.code)) {
                Text(book.name(for: language))
                    .font(.essenceBodyLarge)
                    .foregroundStyle(palette.text)
            }
        }
        .navigationTitle(AppLanguage.localized("Bible", defaultValue: "Bible"))
        .navigationDestination(for: BibleRoute.self) { route in
            BibleRouteDestination(route: route, language: language)
        }
        .background(palette.background)
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
