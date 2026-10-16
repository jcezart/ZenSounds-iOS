import SwiftUI

struct BibleChaptersView: View {
    let bookCode: String
    let language: BibleLanguage

    @Environment(\.essencePalette) private var palette
    @State private var didRecordRecent = false

    private var book: BibleBook? { BibleCatalog.shared.book(code: bookCode) }

    var body: some View {
        Group {
            if let book {
                ScrollView {
                    ChapterGrid(chapters: book.chapters) { chapter in
                        NavigationLink(value: BibleRoute.verses(bookCode: bookCode, chapter: chapter, focusVerse: nil)) {
                            ChapterCell(chapter: chapter, isCurrent: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.screen)
                }
                .navigationTitle(book.name(for: language))
                .onAppear {
                    // Once per visit: coming back from a chapter must not push the book above it.
                    guard !didRecordRecent else { return }
                    didRecordRecent = true
                    UserPreferencesStore.shared.recordRecent(.book(bookCode: book.code))
                }
            } else {
                ContentUnavailableView("Book not found", systemImage: "book.closed")
            }
        }
        .background(palette.background)
        .ambientMiniPlayer(.whenActive)
    }
}

/// Adaptive grid of chapter numbers (chapter list and the reader's "Chapters" sheet).
struct ChapterGrid<Cell: View>: View {
    let chapters: Int
    @ViewBuilder let cell: (Int) -> Cell
    @ScaledMetric(relativeTo: .body) private var cellSize: CGFloat = 56

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellSize), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(1...max(chapters, 1), id: \.self) { chapter in
                cell(chapter)
            }
        }
    }
}

struct ChapterCell: View {
    let chapter: Int
    let isCurrent: Bool
    @Environment(\.essencePalette) private var palette
    @ScaledMetric(relativeTo: .body) private var cellSize: CGFloat = 56

    var body: some View {
        Text("\(chapter)")
            .font(.essenceBodyLarge.monospacedDigit())
            .foregroundStyle(isCurrent ? palette.onAccent : palette.text)
            .frame(minWidth: cellSize, minHeight: cellSize)
            .background(isCurrent ? palette.accent : palette.surface,
                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .accessibilityLabel(Text("Chapter \(chapter)"))
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
