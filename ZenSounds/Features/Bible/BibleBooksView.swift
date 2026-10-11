import SwiftUI

struct BibleBooksView: View {
    @AppStorage(BibleLanguage.storageKey) private var languageRaw = BibleLanguage.systemDefault.rawValue
    @Environment(\.essencePalette) private var palette

    private var language: BibleLanguage { BibleLanguage(rawValue: languageRaw) ?? .systemDefault }
    private var books: [BibleBook] { BibleCatalog.shared.books }

    var body: some View {
        List(books) { book in
            NavigationLink(value: BibleRoute.chapters(bookCode: book.code)) {
                Text(book.name(for: language))
                    .font(.essenceBodyLarge)
                    .foregroundStyle(palette.text)
            }
        }
        .navigationTitle("Bible")
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
