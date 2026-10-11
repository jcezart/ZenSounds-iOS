import SwiftUI

struct SoundsLibraryView: View {
    @EnvironmentObject private var navigation: NavigationModel
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var prefs = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if !prefs.savedMixes.isEmpty {
                    sectionHeader(NSLocalizedString("My Mixes", comment: "Section header for the user's saved sound mixes"))
                    VStack(spacing: 10) {
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
                    .padding(.horizontal)
                }

                ForEach(SoundCategory.allCases) { category in
                    sectionHeader(NSLocalizedString(category.titleKey, value: category.rawValue, comment: ""))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(SoundCatalog.sounds(in: category)) { sound in
                            SoundCard(sound: sound) {
                                audio.play(soundId: sound.id)
                                PlayerPresentation.shared.isFullPlayerPresented = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
        .background(palette.background)
        .navigationTitle("Sounds")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigation.soundsPath.append(SoundsRoute.mixEditor(existingMixId: nil))
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Create mix")
            }
        }
        .navigationDestination(for: SoundsRoute.self) { route in
            switch route {
            case .mixEditor(let existingMixId):
                SoundMixEditorView(existingMixId: existingMixId)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.essenceTitleMedium)
            .foregroundStyle(palette.text)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack { SoundsLibraryView() }
            .environmentObject(NavigationModel())
    }
}
