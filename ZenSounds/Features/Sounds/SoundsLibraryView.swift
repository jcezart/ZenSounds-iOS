import SwiftUI

struct SoundsLibraryView: View {
    @EnvironmentObject private var navigation: NavigationModel
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var prefs = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack(alignment: .top) {
            palette.background
                .ignoresSafeArea()

            SoundsAmbientBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    SoundsLibraryHeader {
                        navigation.soundsPath.append(SoundsRoute.mixEditor(existingMixId: nil))
                    }

                    if !prefs.savedMixes.isEmpty {
                        SoundLibrarySection(title: AppLanguage.localized("My Mixes", defaultValue: "My Mixes")) {
                            ForEach(prefs.savedMixes) { mix in
                                MixRow(
                                    mix: mix,
                                    onTap: {
                                        audio.playMix(mix)
                                        PlayerPresentation.shared.isFullPlayerPresented = true
                                    },
                                    onDelete: { prefs.removeMix(id: mix.id) }
                                )
                            }
                        }
                    }

                    ForEach(SoundCategory.allCases) { category in
                        SoundLibrarySection(
                            title: AppLanguage.localized(category.titleKey, defaultValue: category.defaultTitle)
                        ) {
                            ForEach(SoundCatalog.sounds(in: category)) { sound in
                                SoundRow(sound: sound) {
                                    audio.play(soundId: sound.id)
                                    PlayerPresentation.shared.isFullPlayerPresented = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SoundsRoute.self) { route in
            switch route {
            case .mixEditor(let existingMixId):
                SoundMixEditorView(existingMixId: existingMixId)
            }
        }
    }
}

private struct SoundsAmbientBackground: View {
    @Environment(\.essencePalette) private var palette

    var body: some View {
        Circle()
            .fill(palette.accent.opacity(0.09))
            .frame(width: 280, height: 280)
            .blur(radius: 70)
            .offset(x: 150, y: -150)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct SoundsLibraryHeader: View {
    let onCreateMix: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sounds")
                .font(.essenceHeadlineMedium)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)

            Text("Choose a sound to accompany your reading, prayer, or rest.")
                .font(.essenceBodyMedium)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Button(action: onCreateMix) {
                Label("Create mix", systemImage: "slider.horizontal.3")
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.accent)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(palette.accent.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
    }
}

private struct SoundLibrarySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.essencePalette) private var palette

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.essenceTitleLarge)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)

            LazyVStack(spacing: 12) {
                content
            }
        }
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            SoundsLibraryView()
        }
        .environmentObject(NavigationModel())
    }
}
