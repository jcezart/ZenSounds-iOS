import SwiftUI

struct BibleChaptersView: View {
    let bookCode: String
    let language: BibleLanguage

    @Environment(\.essencePalette) private var palette

    private var book: BibleBook? { BibleCatalog.shared.book(code: bookCode) }

    var body: some View {
        Group {
            if let book {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 12) {
                        ForEach(1...book.chapters, id: \.self) { chapter in
                            NavigationLink(value: BibleRoute.verses(bookCode: bookCode, chapter: chapter, focusVerse: nil)) {
                                Text("\(chapter)")
                                    .font(.essenceBodyLarge)
                                    .foregroundStyle(palette.text)
                                    .frame(width: 56, height: 56)
                                    .background(palette.lilac)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .accessibilityLabel("Chapter \(chapter)")
                        }
                    }
                    .padding()
                }
                .navigationTitle(book.name(for: language))
            } else {
                ContentUnavailableView("Book not found", systemImage: "book.closed")
            }
        }
        .background(palette.background)
        .ambientMiniPlayer(.whenActive)
    }
}
