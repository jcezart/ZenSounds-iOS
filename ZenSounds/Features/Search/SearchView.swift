import SwiftUI

/// Search tab. Before typing: Recent, Favorites (latest verse cards + "See all") and Explore.
/// While typing: results grouped as Books, Passages, Verses, Prayers and Mysteries.
struct SearchView: View {
    @EnvironmentObject private var navigation: NavigationModel
    @StateObject private var model: SearchViewModel
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.essencePalette) private var palette

    @State private var isClearConfirmationPresented = false

    private static let favoritesShown = 3

    /// `initialQuery` is for previews.
    init(initialQuery: String = "") {
        let model = SearchViewModel()
        model.query = initialQuery
        _model = StateObject(wrappedValue: model)
    }

    private var language: BibleLanguage { languageStore.selection.bibleLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Search")
                        .font(.essenceDisplaySmall)
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    SearchField(text: $model.query)
                }

                if model.isActive {
                    SearchResultsView(model: model, language: language)
                } else {
                    recentSection
                    favoritesSection
                    exploreSection
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(palette.background)
        .navigationTitle(AppLanguage.localized("Search", defaultValue: "Search"))
        // Large title + always-visible field like mockup 05 (the system drawer can't show both).
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: language, initial: true) { _, newValue in
            model.language = newValue
        }
        .navigationDestination(for: SearchRoute.self) { route in
            switch route {
            case .favorites:
                FavoritesView()
            case .prayers:
                PrayersView(language: language)
            case .prayer(let id):
                PrayerDetailView(prayerID: id, language: language)
            }
        }
        .navigationDestination(for: BibleRoute.self) { route in
            BibleRouteDestination(route: route, language: language)
        }
        .confirmationDialog("Clear recent items?", isPresented: $isClearConfirmationPresented, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { preferences.clearRecents() }
        } message: {
            Text("This removes the books, chapters and mysteries you opened recently.")
        }
        .ambientMiniPlayer(.whenActive)
    }

    // MARK: Recent

    @ViewBuilder
    private var recentSection: some View {
        let recents = Array(preferences.recents.prefix(RecentsRules.maxDisplayed))
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(title: "Recent", actionTitle: "Clear") {
                    isClearConfirmationPresented = true
                }
                RowCard(items: recents) { item in
                    ShortcutRow(
                        systemImage: SearchPresentation.symbol(for: item),
                        title: Text(verbatim: SearchPresentation.title(for: item, language: language)),
                        subtitle: SearchPresentation.category(for: item),
                        action: { open(item) }
                    )
                }
            }
        }
    }

    // MARK: Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: "Favorites", actionTitle: "See all") {
                navigation.push(SearchRoute.favorites)
            }
            if preferences.favoriteVerses.isEmpty {
                Text("Tap the heart on a verse to save it here.")
                    .font(.essenceBodyMedium)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(preferences.favoriteVerses.prefix(Self.favoritesShown)) { favorite in
                        FavoriteVerseCard(favorite: favorite) {
                            navigation.push(BibleRoute.verses(bookCode: favorite.book, chapter: favorite.chapter, focusVerse: favorite.verseNumber))
                        } onUnfavorite: {
                            withAnimation { preferences.toggleFavoriteVerse(favorite.verse) }
                        }
                    }
                }
            }
        }
    }

    // MARK: Explore

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionTitle("Explore")
            RowCard(items: ExploreDestination.allCases) { destination in
                ShortcutRow(
                    systemImage: destination.systemImage,
                    title: destination.title,
                    subtitle: nil,
                    action: { open(destination) }
                )
            }
        }
    }

    // MARK: Actions

    private func open(_ item: RecentItem) {
        switch item {
        case .chapter(let bookCode, let chapter):
            navigation.push(BibleRoute.verses(bookCode: bookCode, chapter: chapter, focusVerse: nil))
        case .book(let bookCode):
            navigation.push(BibleRoute.chapters(bookCode: bookCode))
        case .mysteries(let set):
            navigation.openRosary(set: set)
        }
    }

    private func open(_ destination: ExploreDestination) {
        switch destination {
        case .bible: navigation.selectedTab = .bible
        case .rosary: navigation.openRosary()
        case .sounds: navigation.push(SoundsRoute.library)
        case .prayers: navigation.push(SearchRoute.prayers)
        }
    }
}

private enum ExploreDestination: CaseIterable, Hashable {
    case bible, rosary, sounds, prayers

    var systemImage: String {
        switch self {
        case .bible: return AppTab.bible.systemImage
        case .rosary: return AppTab.rosary.systemImage
        case .sounds: return "waveform"
        case .prayers: return "hands.and.sparkles"
        }
    }

    var title: Text {
        switch self {
        case .bible: return Text(verbatim: AppLanguage.localized("Bible", defaultValue: "Bible"))
        case .rosary: return Text(verbatim: AppLanguage.localized("Rosary", defaultValue: "Rosary"))
        case .sounds: return Text(verbatim: AppLanguage.localized("Sounds", defaultValue: "Sounds"))
        case .prayers: return Text("Prayers")
        }
    }
}

/// Titles, categories and icons for Search rows (Recent and results).
enum SearchPresentation {
    static func bookName(_ code: String, language: BibleLanguage) -> String {
        BibleCatalog.shared.book(code: code)?.name(for: language) ?? code
    }

    static func title(for item: RecentItem, language: BibleLanguage) -> String {
        switch item {
        case .chapter(let bookCode, let chapter):
            return "\(bookName(bookCode, language: language)) • \(AppLanguage.localized("Chapter", defaultValue: "Chapter")) \(chapter)"
        case .book(let bookCode):
            return bookName(bookCode, language: language)
        case .mysteries(let set):
            return RosaryRepository.shared.mysterySet(set)?.name.text(for: language) ?? set.rawValue
        }
    }

    static func category(for item: RecentItem) -> String {
        switch item {
        case .chapter, .book: return AppLanguage.localized("Bible", defaultValue: "Bible")
        case .mysteries: return AppLanguage.localized("Rosary", defaultValue: "Rosary")
        }
    }

    static func symbol(for item: RecentItem) -> String {
        switch item {
        case .chapter, .book: return AppTab.bible.systemImage
        case .mysteries: return AppTab.rosary.systemImage
        }
    }

    static func reference(_ passage: PassageReference, language: BibleLanguage) -> String {
        let base = "\(bookName(passage.bookCode, language: language)) \(passage.chapter)"
        return passage.verse.map { "\(base):\($0)" } ?? base
    }
}

// MARK: - Building blocks

/// Rounded search field: magnifying glass, "Books, passages and prayers", clear button.
private struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(palette.secondaryText)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: Text("Books, passages and prayers").foregroundStyle(palette.secondaryText)) {
                Text("Search")
            }
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .foregroundStyle(palette.text)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.secondaryText)
                        .frame(minWidth: 32, minHeight: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear text"))
            }
        }
        .font(.essenceBodyLarge)
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xs)
        .frame(minHeight: 44)
        .background(palette.surface, in: Capsule())
        .overlay(Capsule().stroke(isFocused ? palette.accent.opacity(0.6) : palette.outline, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }
}

/// Section title with a trailing accent-colored action ("Clear", "See all").
struct SectionHeader: View {
    let title: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let action: () -> Void
    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionTitle(title)
            Spacer(minLength: Spacing.sm)
            Button(actionTitle, action: action)
                .font(.essenceLabelLarge)
                .foregroundStyle(palette.accent)
        }
    }
}

/// Rounded surface card of rows with separators that start after the icon.
struct RowCard<Item: Hashable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row
    @Environment(\.essencePalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                row(item)
                if index < items.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

/// Favorite verse card: reference, serif text, Share (left) and a filled heart that unfavorites (right).
private struct FavoriteVerseCard: View {
    let favorite: FavoriteVerse
    let onOpen: () -> Void
    let onUnfavorite: () -> Void
    @Environment(\.essencePalette) private var palette

    private var reference: String {
        "\(SearchPresentation.bookName(favorite.book, language: favorite.language)) \(favorite.chapter):\(favorite.verseNumber)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(reference)
                        .font(.essenceLabelMedium)
                        .foregroundStyle(palette.accent)
                    Text(favorite.text)
                        .font(.scriptureBody)
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens the chapter"))

            HStack {
                ShareLink(item: "\(favorite.text) — \(reference) · Orante") {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Share verse"))
                Spacer()
                Button(action: onUnfavorite) {
                    Image(systemName: "heart.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Remove from favorites"))
            }
            .font(.body.weight(.medium))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, -10)
            .padding(.bottom, -Spacing.xs)
        }
        .padding(Spacing.md)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Results

private struct SearchResultsView: View {
    @ObservedObject var model: SearchViewModel
    let language: BibleLanguage
    @EnvironmentObject private var navigation: NavigationModel
    @Environment(\.essencePalette) private var palette

    private var results: SearchViewModel.Results { model.results }

    var body: some View {
        if results.isEmpty && !model.isSearchingVerses {
            ContentUnavailableView.search(text: model.query)
                .padding(.top, Spacing.xxl)
        } else {
            if !results.books.isEmpty {
                group("Books") {
                    RowCard(items: results.books) { book in
                        ShortcutRow(
                            systemImage: "book.closed",
                            title: Text(verbatim: book.name(for: language)),
                            subtitle: AppLanguage.localized("Bible", defaultValue: "Bible"),
                            action: { navigation.push(BibleRoute.chapters(bookCode: book.code)) }
                        )
                    }
                }
            }
            if !results.passages.isEmpty {
                group("Passages") {
                    RowCard(items: results.passages) { passage in
                        ShortcutRow(
                            systemImage: "text.book.closed",
                            title: Text(verbatim: SearchPresentation.reference(passage, language: language)),
                            subtitle: model.passageTexts[passage] ?? AppLanguage.localized("Bible", defaultValue: "Bible"),
                            action: {
                                navigation.push(BibleRoute.verses(bookCode: passage.bookCode, chapter: passage.chapter, focusVerse: passage.verse))
                            }
                        )
                    }
                }
            }
            if !results.verses.isEmpty || model.isSearchingVerses {
                versesGroup
            }
            if !results.prayers.isEmpty {
                group("Prayers") {
                    RowCard(items: results.prayers) { hit in
                        ShortcutRow(
                            systemImage: "hands.and.sparkles",
                            title: Text(verbatim: RosaryLabels.prayerName(hit.kind, language: language)),
                            subtitle: AppLanguage.localized("Rosary", defaultValue: "Rosary"),
                            action: { navigation.push(SearchRoute.prayer(id: hit.id)) }
                        )
                    }
                }
            }
            if !results.mysteries.isEmpty {
                group("Mysteries") {
                    RowCard(items: results.mysteries) { hit in
                        let set = RosaryRepository.shared.mysterySet(hit.set)
                        let setName = set?.name.text(for: language) ?? hit.set.rawValue
                        let mysteryName = RosaryRepository.shared.mystery(hit.mysteryID)?.name.text(for: language)
                        ShortcutRow(
                            systemImage: AppTab.rosary.systemImage,
                            title: Text(verbatim: mysteryName ?? setName),
                            subtitle: mysteryName == nil ? AppLanguage.localized("Rosary", defaultValue: "Rosary") : setName,
                            action: { navigation.openRosary(set: hit.set) }
                        )
                    }
                }
            }
        }
    }

    private var versesGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SectionTitle("Verses")
                if model.isSearchingVerses {
                    ProgressView().controlSize(.small)
                }
            }
            if !results.verses.isEmpty {
                RowCard(items: results.verses) { verse in
                    Button {
                        navigation.push(BibleRoute.verses(bookCode: verse.book, chapter: verse.chapter, focusVerse: verse.number))
                    } label: {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(verbatim: "\(SearchPresentation.bookName(verse.book, language: language)) \(verse.chapter):\(verse.number)")
                                    .font(.essenceLabelMedium)
                                    .foregroundStyle(palette.accent)
                                Text(verse.text)
                                    .font(.scriptureCaption)
                                    .foregroundStyle(palette.text)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: Spacing.xs)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.secondaryText)
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                        }
                        .padding(Spacing.sm)
                        .padding(.leading, 52)
                        .overlay(alignment: .topLeading) {
                            Image(systemName: "text.quote")
                                .font(.title3)
                                .foregroundStyle(palette.accent)
                                .frame(width: 40, height: 40)
                                .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                                .padding(Spacing.sm)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionTitle(title)
            content()
        }
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            SearchView()
        }
        .environmentObject(NavigationModel())
    }
}

#Preview("Dark") {
    ZenSoundsTheme {
        NavigationStack {
            SearchView()
        }
        .environmentObject(NavigationModel())
    }
    .preferredColorScheme(.dark)
}

#Preview("Results") {
    ZenSoundsTheme {
        NavigationStack {
            SearchView(initialQuery: "jo 3:16")
        }
        .environmentObject(NavigationModel())
    }
}

#Preview("Results text") {
    ZenSoundsTheme {
        NavigationStack {
            SearchView(initialQuery: "ave maria")
        }
        .environmentObject(NavigationModel())
    }
    .preferredColorScheme(.dark)
}
