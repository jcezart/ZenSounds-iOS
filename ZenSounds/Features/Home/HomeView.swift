import SwiftUI

/// Today tab: Word of the Day, "Continue" shortcuts (Bible, Rosary), an Explore card and the ambient
/// sound mini-player at the end of the content.
struct HomeView: View {
    @EnvironmentObject private var navigation: NavigationModel
    @StateObject private var viewModel = DailyWordViewModel()
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var narration = BibleNarrationService.shared
    @ObservedObject private var rosaryProgress = RosaryProgressStore.shared
    @Environment(\.essencePalette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    @State private var isSettingsPresented = false

    /// Explore keeps the previous behavior (the Word of the Day's book), with Psalms before it loads.
    private var exploreBookCode: String { viewModel.state.reading?.book ?? "PSA" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header

                DailyWordCard(
                    state: viewModel.state,
                    isFavorite: viewModel.state.verse.map(preferences.isFavoriteVerse) ?? false,
                    onToggleFavorite: toggleDailyFavorite,
                    onShuffle: shuffleDailyWord,
                    onExplore: openDailyReading
                )

                continueSection
                exploreSection

                AmbientMiniPlayer()
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .task {
            viewModel.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.refresh()
            }
        }
        .onChange(of: languageStore.selection) {
            viewModel.refresh()
        }
        .navigationDestination(for: BibleRoute.self) { route in
            BibleRouteDestination(route: route, language: viewModel.language)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Orante")
                    .font(.scriptureHeadline)
                    .foregroundStyle(palette.accent)
                Text("Today")
                    .font(.essenceDisplaySmall)
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            SettingsButton { isSettingsPresented = true }
        }
    }

    // MARK: Continue

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionTitle("Continue")
            VStack(spacing: 0) {
                ShortcutRow(
                    systemImage: "book.pages",
                    title: preferences.readingPosition == nil ? Text("Start reading") : Text("Resume the Bible"),
                    subtitle: readingSubtitle,
                    action: openReadingPosition
                )
                Divider().padding(.leading, 64)
                ShortcutRow(
                    systemImage: AppTab.rosary.systemImage,
                    title: Text("Pray the Rosary"),
                    subtitle: rosarySubtitle,
                    action: { navigation.selectedTab = .rosary }
                )
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private var readingSubtitle: String {
        let position = preferences.readingPosition ?? ReadingPosition(bookCode: "GEN", chapter: 1)
        let name = BibleCatalog.shared.book(code: position.bookCode)?.name(for: viewModel.language) ?? position.bookCode
        return "\(name) · \(AppLanguage.localized("Chapter", defaultValue: "Chapter")) \(position.chapter)"
    }

    /// Mysteries of the Rosary in progress, otherwise the ones suggested for today.
    private var rosarySubtitle: String {
        let setID = rosaryProgress.progress?.mysterySet ?? MysterySchedule.suggestedSet(for: Date())
        return RosaryRepository.shared.mysterySet(setID)?.name.text(for: viewModel.language) ?? ""
    }

    // MARK: Explore

    private var exploreSection: some View {
        let bookName = BibleCatalog.shared.book(code: exploreBookCode)?.name(for: viewModel.language) ?? exploreBookCode
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionTitle("Explore")
            Button(action: openExploreBook) {
                ZStack(alignment: .leading) {
                    Image("ExplorePsalms")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .accessibilityHidden(true)
                    // Keeps the title legible over the artwork in light and dark mode.
                    LinearGradient(
                        colors: [.black.opacity(0.55), .black.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(bookName)
                                .font(.scriptureTitle)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("Find comfort in every word.")
                                .font(.essenceBodyMedium)
                                .foregroundStyle(.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Spacing.sm)
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                            .accessibilityHidden(true)
                    }
                    .padding(Spacing.md)
                }
                .frame(minHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens the book"))
        }
    }

    // MARK: Actions

    private func toggleDailyFavorite() {
        guard let verse = viewModel.state.verse else { return }
        preferences.toggleFavoriteVerse(verse)
    }

    private func shuffleDailyWord() {
        if let verse = viewModel.state.verse, narration.isCurrent(verse) {
            narration.stop()
        }
        viewModel.shuffle()
    }

    private func openDailyReading() {
        guard let reading = viewModel.state.reading else { return }
        navigation.openBible(bookCode: reading.book, chapter: reading.chapter, focusVerse: reading.verse)
    }

    /// Resumes the last chapter read, or starts at Genesis 1.
    private func openReadingPosition() {
        let position = preferences.readingPosition ?? ReadingPosition(bookCode: "GEN", chapter: 1)
        navigation.openBible(bookCode: position.bookCode, chapter: position.chapter)
    }

    private func openExploreBook() {
        navigation.selectedTab = .bible
        navigation.biblePath = NavigationPath()
        navigation.biblePath.append(BibleRoute.chapters(bookCode: exploreBookCode))
    }
}

// MARK: - Shared building blocks

/// Section heading used across the redesigned tabs.
struct SectionTitle: View {
    let title: LocalizedStringKey
    @Environment(\.essencePalette) private var palette

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.essenceTitleLarge)
            .foregroundStyle(palette.text)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Gear button that opens Settings (Today and Rosary headers).
struct SettingsButton: View {
    let action: () -> Void
    @Environment(\.essencePalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.title3.weight(.regular))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(Text("Settings"))
    }
}

/// Icon + title + subtitle + chevron row ("Continue", Search lists).
struct ShortcutRow: View {
    let systemImage: String
    let title: Text
    let subtitle: String?
    var badge: PremiumFeature? = nil
    let action: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 40)
                    .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.essenceTitleMedium)
                        .foregroundStyle(palette.text)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.essenceBodySmall)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: Spacing.xs)
                if let badge { PremiumLockBadge(feature: badge) }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            HomeView()
        }
        .environmentObject(NavigationModel())
    }
}

#Preview("Dark") {
    ZenSoundsTheme {
        NavigationStack {
            HomeView()
        }
        .environmentObject(NavigationModel())
    }
    .preferredColorScheme(.dark)
}
