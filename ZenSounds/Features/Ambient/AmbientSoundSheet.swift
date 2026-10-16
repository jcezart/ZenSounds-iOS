import SwiftUI

/// "Ambient sound" sheet: featured Biblical Soundscapes (The Good Shepherd is free), every sound with
/// play/pause, active check, favorite and lock, master volume, sleep timer and "Create mix".
struct AmbientSoundSheet: View {
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @ObservedObject private var presentation = PlayerPresentation.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.essencePalette) private var palette
    @State private var isTimerPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                soundscapes
                ForEach(SoundCategory.allCases) { category in
                    soundSection(category)
                }
                volume
                if audio.isActive {
                    playbackLinks
                }
                createMixButton
                libraryLink
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isTimerPresented) { TimerSheetView() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Ambient sound")
                    .font(.essenceHeadlineMedium)
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text("For your reading or prayer.")
                    .font(.essenceBodyMedium)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Button {
                presentation.isAmbientSheetPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Close"))
        }
    }

    private var soundscapes: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Spacing.sm) {
                ForEach(BiblicalSoundscapeCatalog.all) { soundscape in
                    BiblicalSoundscapeCard(
                        soundscape: soundscape,
                        onPlay: { AmbientPlayback.start(.soundscape(id: soundscape.id)) },
                        onOpenPassage: {
                            presentation.dismissAmbientSheet {
                                NavigationModel.shared.openBible(bookCode: soundscape.bookCode, chapter: soundscape.chapter)
                            }
                        }
                    )
                    .containerRelativeFrame(.horizontal, count: 1, spacing: Spacing.sm)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func soundSection(_ category: SoundCategory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(AppLanguage.localized(category.titleKey, defaultValue: category.defaultTitle))
                .font(.essenceTitleMedium)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(SoundCatalog.sounds(in: category)) { sound in
                    AmbientSoundRow(sound: sound)
                    if sound.id != SoundCatalog.sounds(in: category).last?.id {
                        Divider().padding(.leading, 74)
                    }
                }
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private var volume: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Volume")
                .font(.essenceTitleMedium)
                .foregroundStyle(palette.text)
            HStack(spacing: Spacing.sm) {
                Image(systemName: "speaker.fill").foregroundStyle(palette.secondaryText).accessibilityHidden(true)
                Slider(value: $audio.masterVolume, in: 0...1)
                    .tint(palette.accent)
                    .accessibilityLabel(Text("Master volume"))
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(palette.secondaryText).accessibilityHidden(true)
            }
        }
    }

    private var playbackLinks: some View {
        VStack(spacing: 0) {
            sheetRow(title: Text("Sleep timer"), systemImage: audio.timerDeadline == nil ? "timer" : "timer.circle.fill") {
                isTimerPresented = true
            }
            Divider().padding(.leading, 52)
            sheetRow(title: Text("Open player"), systemImage: "play.rectangle") {
                presentation.dismissAmbientSheet { PlayerPresentation.shared.isFullPlayerPresented = true }
            }
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var createMixButton: some View {
        Button {
            // The sheet controls what's playing, so it uses the player's `create_mix` source.
            SuperwallService.shared.gate(.mixer, parameters: ["source": "player"]) {
                presentation.dismissAmbientSheet {
                    NavigationModel.shared.push(SoundsRoute.mixEditor(existingMixId: nil))
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "slider.horizontal.3")
                Text("Create mix")
                PremiumLockBadge(feature: .mixer)
            }
            .font(.essenceLabelLarge)
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(palette.surface, in: Capsule())
            .overlay(Capsule().stroke(palette.outline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var libraryLink: some View {
        Button {
            presentation.dismissAmbientSheet { NavigationModel.shared.openSoundsLibrary() }
        } label: {
            Text("Full sound library")
                .font(.essenceLabelLarge)
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func sheetRow(title: Text, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                title
                    .font(.essenceBodyLarge)
                    .foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One sound in the ambient sheet: tap to play (or pause the one playing), favorite, lock if paid.
private struct AmbientSoundRow: View {
    let sound: SoundItem

    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    private var isCurrent: Bool { audio.activeSoundId == sound.id && audio.layers.count == 1 }
    private var title: String { AppLanguage.localized(sound.titleKey, defaultValue: sound.id) }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: primaryAction) {
                HStack(spacing: Spacing.sm) {
                    SoundArtwork(soundID: sound.id, size: 50)
                    Text(title)
                        .font(.essenceBodyLarge)
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                    Spacer(minLength: Spacing.xs)
                    PremiumLockBadge(feature: .sound(id: sound.id))
                    if isCurrent {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(palette.text)
                            .frame(width: 36, height: 36)
                            .background(palette.surfaceElevated, in: Circle())
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(isCurrent ? (audio.isPlaying ? Text("Playing") : Text("Paused")) : Text(verbatim: ""))
            .accessibilityHint(isCurrent ? Text("Pause or resume") : Text("Play sound"))

            Button {
                preferences.toggleFavoriteSound(sound.id)
            } label: {
                Image(systemName: preferences.isFavoriteSound(sound.id) ? "heart.fill" : "heart")
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(preferences.isFavoriteSound(sound.id)
                ? Text("Remove \(title) from favorites")
                : Text("Add \(title) to favorites"))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }

    private func primaryAction() {
        if isCurrent {
            audio.togglePlayPause()
        } else {
            AmbientPlayback.start(.sound(id: sound.id))
        }
    }
}

#Preview {
    ZenSoundsTheme { AmbientSoundSheet() }
}
