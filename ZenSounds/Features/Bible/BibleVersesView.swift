import SwiftUI

/// Reader: serif chapter text with numbered verses. Tapping a verse opens a small action block
/// (Listen — `bible_narration` — Favorite, Share); tapping it again or another verse moves/closes it.
/// "Aa" scales the text on top of Dynamic Type; "…" lists chapters, moves between chapters and shares.
struct BibleVersesView: View {
    let language: BibleLanguage
    var focusVerse: Int? = nil

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @ObservedObject private var narration = BibleNarrationService.shared
    @Environment(\.essencePalette) private var palette
    @AppStorage(ReadingFontScale.storageKey) private var storedFontScale = ReadingFontScale.defaultValue
    @ScaledMetric(relativeTo: .title3) private var baseTextSize: CGFloat = 20

    /// The route's chapter; "…" and the footer change it in place instead of growing the stack.
    private let initialLocation: ChapterLocation
    @State private var location: ChapterLocation
    @State private var verses: [Verse] = []
    @State private var subtitle: String?
    @State private var isLoading = true
    @State private var selectedVerse: Int?
    @State private var isChapterListPresented = false
    @State private var isTextSizePresented = false

    init(bookCode: String, chapter: Int, language: BibleLanguage, focusVerse: Int? = nil) {
        self.language = language
        self.focusVerse = focusVerse
        let location = ChapterLocation(bookCode: bookCode, chapter: chapter)
        initialLocation = location
        _location = State(initialValue: location)
    }

    private var book: BibleBook? { BibleCatalog.shared.book(code: location.bookCode) }
    private var bookName: String { book?.name(for: language) ?? location.bookCode }
    private var title: String { "\(bookName) \(location.chapter)" }
    private var fontScale: Double { ReadingFontScale.clamped(storedFontScale) }
    private var textSize: CGFloat { baseTextSize * fontScale }
    private var previousLocation: ChapterLocation? { ChapterNavigation.previous(of: location, in: BibleCatalog.shared.books) }
    private var nextLocation: ChapterLocation? { ChapterNavigation.next(of: location, in: BibleCatalog.shared.books) }
    /// The deep-link/Word of the Day highlight only applies to the chapter it was opened with.
    private var activeFocusVerse: Int? { location == initialLocation ? focusVerse : nil }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                        .id(Self.topID)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if verses.isEmpty {
                        ContentUnavailableView("Chapter unavailable", systemImage: "book.closed")
                            .padding(.top, 60)
                    } else {
                        LazyVStack(alignment: .leading, spacing: Spacing.xxs) {
                            ForEach(verses) { verse in
                                VerseParagraph(
                                    verse: verse,
                                    text: attributedText(for: verse),
                                    lineSpacing: textSize * 0.35,
                                    isSelected: selectedVerse == verse.number,
                                    isFavorite: prefs.isFavoriteVerse(verse),
                                    background: rowBackground(for: verse),
                                    isNarrating: narration.isCurrent(verse),
                                    onTap: { toggleSelection(verse.number) },
                                    onToggleFavorite: { prefs.toggleFavoriteVerse(verse) },
                                    shareText: shareText(for: verse)
                                )
                                .id(verse.number)
                            }
                        }
                        chapterFooter
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)
            }
            .task(id: "\(location.bookCode):\(location.chapter):\(language.rawValue)") {
                await load()
                if let activeFocusVerse {
                    await Task.yield()
                    withAnimation { proxy.scrollTo(activeFocusVerse, anchor: .center) }
                } else {
                    proxy.scrollTo(Self.topID, anchor: .top)
                }
            }
        }
        .background(palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                textSizeButton
                chapterMenu
            }
        }
        .sheet(isPresented: $isChapterListPresented) {
            ChapterPickerSheet(bookCode: location.bookCode, bookName: bookName, current: location.chapter) { chapter in
                go(to: ChapterLocation(bookCode: location.bookCode, chapter: chapter))
            }
        }
        .ambientMiniPlayer(.always)
    }

    private static let topID = "reader.top"

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: "\(bookName) · \(AppLanguage.localized("Chapter", defaultValue: "Chapter")) \(location.chapter)")
                .font(.essenceLabelMedium)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.scriptureTitle)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                // Psalm superscription, from the source text (no invented section titles).
                Text(subtitle)
                    .font(.system(size: textSize * 0.85, design: .serif).italic())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xxs)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func attributedText(for verse: Verse) -> AttributedString {
        var number = AttributedString("\(verse.number)\u{00A0}")
        number.font = .system(size: textSize * 0.6, weight: .semibold)
        number.foregroundColor = palette.accent
        number.baselineOffset = textSize * 0.28
        var body = AttributedString(verse.text)
        body.font = .system(size: textSize, design: .serif)
        body.foregroundColor = palette.text
        return number + body
    }

    private func rowBackground(for verse: Verse) -> Color {
        if narration.isCurrent(verse) { return palette.lilac.opacity(0.82) }
        if selectedVerse == verse.number { return palette.surface }
        return activeFocusVerse == verse.number ? palette.lilac.opacity(0.6) : .clear
    }

    private func shareText(for verse: Verse) -> String {
        "\(verse.text) — \(bookName) \(verse.chapter):\(verse.number) · Orante"
    }

    // MARK: Toolbar

    private var textSizeButton: some View {
        Button {
            isTextSizePresented = true
        } label: {
            Text(verbatim: "Aa")
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel(Text("Text size"))
        .popover(isPresented: $isTextSizePresented) {
            HStack(spacing: Spacing.md) {
                Button {
                    if let smaller = ReadingFontScale.smaller(than: fontScale) { storedFontScale = smaller }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .frame(width: 44, height: 44)
                }
                .disabled(ReadingFontScale.smaller(than: fontScale) == nil)
                .accessibilityLabel(Text("Smaller text"))

                Text(fontScale, format: .percent.precision(.fractionLength(0)))
                    .font(.essenceLabelLarge.monospacedDigit())
                    .frame(minWidth: 52)

                Button {
                    if let larger = ReadingFontScale.larger(than: fontScale) { storedFontScale = larger }
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .frame(width: 44, height: 44)
                }
                .disabled(ReadingFontScale.larger(than: fontScale) == nil)
                .accessibilityLabel(Text("Larger text"))
            }
            .font(.title3)
            .foregroundStyle(palette.accent)
            .padding(Spacing.sm)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var chapterMenu: some View {
        Menu {
            Button {
                isChapterListPresented = true
            } label: {
                Label("Chapters", systemImage: "square.grid.3x3")
            }
            Button {
                if let previousLocation { go(to: previousLocation) }
            } label: {
                Label("Previous chapter", systemImage: "chevron.left")
            }
            .disabled(previousLocation == nil)
            Button {
                if let nextLocation { go(to: nextLocation) }
            } label: {
                Label("Next chapter", systemImage: "chevron.right")
            }
            .disabled(nextLocation == nil)
            if !verses.isEmpty {
                ShareLink(item: ChapterShareText.make(title: title, verses: verses)) {
                    Label("Share chapter", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("More"))
    }

    // MARK: Footer

    private var chapterFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                previousButton
                Spacer(minLength: Spacing.sm)
                nextButton
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                nextButton
                previousButton
            }
        }
        .font(.essenceLabelLarge)
        .padding(.top, Spacing.lg)
    }

    @ViewBuilder
    private var previousButton: some View {
        if let previousLocation {
            Button {
                go(to: previousLocation)
            } label: {
                Label("Previous chapter", systemImage: "chevron.left")
                    .fixedSize()
            }
            .buttonStyle(.bordered)
            .tint(palette.accent)
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        if let nextLocation {
            Button {
                go(to: nextLocation)
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text("Next chapter")
                    Image(systemName: "chevron.right")
                }
                .fixedSize()
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .foregroundStyle(palette.onAccent)
        }
    }

    // MARK: Actions

    private func toggleSelection(_ number: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedVerse = selectedVerse == number ? nil : number
        }
    }

    private func go(to newLocation: ChapterLocation) {
        selectedVerse = nil
        location = newLocation
    }

    private func load() async {
        isLoading = true
        let current = location
        async let loadedVerses = BibleRepository.shared.chapterAsync(bookCode: current.bookCode, number: current.chapter, language: language)
        async let loadedSubtitle = BibleRepository.shared.subtitleAsync(bookCode: current.bookCode, number: current.chapter, language: language)
        let (newVerses, newSubtitle) = await (loadedVerses, loadedSubtitle)
        guard current == location else { return }
        verses = newVerses
        subtitle = newSubtitle
        isLoading = false
        if !verses.isEmpty {
            prefs.saveReading(bookCode: current.bookCode, chapter: current.chapter)
            prefs.recordRecent(.chapter(bookCode: current.bookCode, chapter: current.chapter))
        }
    }
}

/// One verse; when selected it shows the Listen / Favorite / Share block under the text.
private struct VerseParagraph: View {
    let verse: Verse
    let text: AttributedString
    let lineSpacing: CGFloat
    let isSelected: Bool
    let isFavorite: Bool
    let background: Color
    let isNarrating: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    let shareText: String

    @Environment(\.essencePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button(action: onTap) {
                Text(text)
                    .lineSpacing(lineSpacing)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "\(verse.number). \(verse.text)"))
            .accessibilityHint(isSelected ? Text("Hides verse actions") : Text("Shows verse actions"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: Text("Listen to verse")) {
                VerseNarrationStarter.start(verse, isDailyWord: false)
            }
            .accessibilityAction(named: isFavorite ? Text("Remove favorite") : Text("Add favorite"), onToggleFavorite)

            if isSelected {
                actions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 6)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay {
            if isNarrating {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .stroke(palette.accent.opacity(0.7), lineWidth: 1.5)
            }
        }
        .padding(.horizontal, -Spacing.xs)
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.md) { actionButtons }
            VStack(alignment: .leading, spacing: Spacing.sm) { actionButtons }
        }
        .font(.essenceLabelLarge)
        .foregroundStyle(palette.accent)
        .buttonStyle(.borderless)
        .padding(.vertical, Spacing.xxs)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VerseNarrationControls(verse: verse, style: .labeled)
            .fixedSize()
        Button(action: onToggleFavorite) {
            Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                .fixedSize()
        }
        ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
                .fixedSize()
        }
    }
}

/// "Chapters" from the reader's "…" menu: the current book's chapters, current one highlighted.
private struct ChapterPickerSheet: View {
    let bookCode: String
    let bookName: String
    let current: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.essencePalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                ChapterGrid(chapters: BibleCatalog.shared.book(code: bookCode)?.chapters ?? 0) { chapter in
                    Button {
                        onSelect(chapter)
                        dismiss()
                    } label: {
                        ChapterCell(chapter: chapter, isCurrent: chapter == current)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.screen)
            }
            .background(palette.background)
            .navigationTitle(bookName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            BibleVersesView(bookCode: "PSA", chapter: 23, language: .pt)
        }
    }
}

#Preview("Dark") {
    ZenSoundsTheme {
        NavigationStack {
            BibleVersesView(bookCode: "PSA", chapter: 23, language: .pt, focusVerse: 4)
        }
    }
    .preferredColorScheme(.dark)
}
