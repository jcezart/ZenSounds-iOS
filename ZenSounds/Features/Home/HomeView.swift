import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var navigation: NavigationModel
    @StateObject private var viewModel = DailyWordViewModel()
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var narration = BibleNarrationService.shared
    @Environment(\.essencePalette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    @State private var isSettingsPresented = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HomeBrandHeader {
                    isSettingsPresented = true
                }

                DailyWordCard(
                    state: viewModel.state,
                    isFavorite: viewModel.state.verse.map(preferences.isFavoriteVerse) ?? false,
                    onToggleFavorite: toggleDailyFavorite,
                    onShuffle: shuffleDailyWord,
                    onExplore: openDailyReading
                )

                HomeReadingShortcuts(
                    position: preferences.readingPosition,
                    dailyBookCode: viewModel.state.reading?.book,
                    language: viewModel.language,
                    onResume: openReadingPosition,
                    onExplore: openDailyBook
                )

                HomeSoundPauseSection(
                    isRainPlaying: audio.activeSoundId == "Rain" && audio.isPlaying,
                    isForestPlaying: audio.activeSoundId == "Forest" && audio.isPlaying,
                    onPlayRain: { play(soundID: "Rain") },
                    onPlayForest: { play(soundID: "Forest") },
                    onOpenMix: openMixEditor,
                    onSeeAll: { navigation.selectedTab = .sounds }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // Leaves the final row fully scrollable above the compact player and tab bar.
            .padding(.bottom, audio.isActive ? 160 : 120)
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
        navigation.openBible(
            bookCode: reading.book,
            chapter: reading.chapter,
            focusVerse: reading.verse
        )
    }

    private func openReadingPosition() {
        let position = preferences.readingPosition ?? ReadingPosition(bookCode: "GEN", chapter: 1)
        navigation.openBible(bookCode: position.bookCode, chapter: position.chapter)
    }

    private func openDailyBook() {
        guard let bookCode = viewModel.state.reading?.book else { return }
        navigation.selectedTab = .bible
        navigation.biblePath = NavigationPath()
        navigation.biblePath.append(BibleRoute.chapters(bookCode: bookCode))
    }

    private func play(soundID: String) {
        audio.play(soundId: soundID)
        PlayerPresentation.shared.isFullPlayerPresented = true
    }

    private func openMixEditor() {
        navigation.selectedTab = .sounds
        navigation.soundsPath = NavigationPath()
        navigation.soundsPath.append(SoundsRoute.mixEditor(existingMixId: nil))
    }
}

private struct HomeBrandHeader: View {
    let onOpenSettings: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                Text(verbatim: "Zen")
                    .foregroundStyle(palette.text)
                Text(verbatim: "Sounds")
                    .foregroundStyle(palette.accent)
            }
            .font(.essenceTitleLarge)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("ZenSounds")

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
    }
}

private struct HomeReadingShortcuts: View {
    let position: ReadingPosition?
    let dailyBookCode: String?
    let language: BibleLanguage
    let onResume: () -> Void
    let onExplore: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onResume) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 24, weight: .medium))
                    Spacer(minLength: 2)
                    Text(position == nil ? "Start the Bible" : "Resume the Bible")
                        .font(.essenceTitleMedium)
                    Text(readingSubtitle)
                        .font(.essenceBodySmall)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        ProgressView(value: readingProgress)
                            .tint(palette.accent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                .padding(16)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onExplore) {
                ZStack(alignment: .bottomTrailing) {
                    BotanicalArtwork(color: palette.foliage.opacity(0.78))
                        .frame(width: 74, height: 140)
                        .offset(x: 12, y: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Explore")
                            .font(.essenceBodyMedium)
                            .foregroundStyle(palette.secondaryText)
                        Text(exploreBookName)
                            .font(.essenceTitleMedium)
                            .foregroundStyle(palette.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                            .padding(.trailing, 42)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(palette.lilac, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(dailyBookCode == nil)
        }
    }

    private var readingSubtitle: String {
        let current = position ?? ReadingPosition(bookCode: "GEN", chapter: 1)
        let name = BibleCatalog.shared.book(code: current.bookCode)?.name(for: language) ?? current.bookCode
        return "\(name) · \(AppLanguage.localized("Chapter", defaultValue: "Chapter")) \(current.chapter)"
    }

    private var readingProgress: Double {
        let current = position ?? ReadingPosition(bookCode: "GEN", chapter: 1)
        let chapters = BibleCatalog.shared.book(code: current.bookCode)?.chapters ?? 1
        return Double(current.chapter) / Double(max(chapters, 1))
    }

    private var exploreBookName: String {
        guard let code = dailyBookCode,
              let book = BibleCatalog.shared.book(code: code) else {
            return AppLanguage.localized("Bible", defaultValue: "Bible")
        }
        return book.name(for: language)
    }
}

private struct HomeSoundPauseSection: View {
    let isRainPlaying: Bool
    let isForestPlaying: Bool
    let onPlayRain: () -> Void
    let onPlayForest: () -> Void
    let onOpenMix: () -> Void
    let onSeeAll: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("A pause with sound")
                    .font(.essenceTitleMedium)
                    .foregroundStyle(palette.text)
                Spacer()
                Button("See all", action: onSeeAll)
                    .font(.essenceLabelMedium)
            }

            HStack(alignment: .top, spacing: 14) {
                HomeSoundCircle(
                    soundID: "Rain",
                    title: "sound_rain",
                    isPlaying: isRainPlaying,
                    action: onPlayRain
                )
                HomeSoundCircle(
                    soundID: "Forest",
                    title: "sound_forest",
                    isPlaying: isForestPlaying,
                    action: onPlayForest
                )
                HomeMixCircle(action: onOpenMix)
            }
        }
    }
}

private struct HomeSoundCircle: View {
    let soundID: String
    let title: LocalizedStringKey
    let isPlaying: Bool
    let action: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(soundID)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(Circle())
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 31, height: 31)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.text)
                }
                .frame(height: 108)
                Text(title)
                    .font(.essenceBodySmall)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct HomeMixCircle: View {
    let action: () -> Void
    @Environment(\.essencePalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(palette.outline)
                    .frame(height: 108)
                    .overlay {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                Text("My mix")
                    .font(.essenceBodySmall)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct BotanicalArtwork: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var stem = Path()
            stem.move(to: CGPoint(x: size.width * 0.48, y: size.height * 1.05))
            stem.addCurve(
                to: CGPoint(x: size.width * 0.62, y: size.height * 0.06),
                control1: CGPoint(x: size.width * 0.60, y: size.height * 0.68),
                control2: CGPoint(x: size.width * 0.53, y: size.height * 0.36)
            )
            context.stroke(stem, with: .color(color), lineWidth: 1.6)

            let leaves: [(Double, Double, Double)] = [
                (0.48, 0.20, -0.34), (0.67, 0.30, 0.34),
                (0.42, 0.43, -0.42), (0.68, 0.54, 0.38),
                (0.42, 0.66, -0.46), (0.64, 0.80, 0.42)
            ]
            for (x, y, rotation) in leaves {
                var leaf = Path(ellipseIn: CGRect(
                    x: size.width * x - 11,
                    y: size.height * y - 25,
                    width: 22,
                    height: 50
                ))
                let transform = CGAffineTransform(translationX: size.width * x, y: size.height * y)
                    .rotated(by: rotation)
                    .translatedBy(x: -size.width * x, y: -size.height * y)
                leaf = leaf.applying(transform)
                context.fill(leaf, with: .color(color))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
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
