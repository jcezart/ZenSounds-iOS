import SwiftUI
import UIKit

/// Full player screen for both single-sound and mix playback. Reflects `AudioEngine`'s real
/// state directly (no separate "UI thinks it's playing" flag) — play/pause/close always match
/// what's actually coming out of the speakers.
struct PlayerView: View {
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var prefs = UserPreferencesStore.shared
    @ObservedObject private var playerPresentation = PlayerPresentation.shared
    @Environment(\.essencePalette) private var palette

    @State private var isTimerSheetPresented = false
    @State private var isAddSoundSheetPresented = false
    @State private var isSaveMixAlertPresented = false
    @State private var mixNameDraft = ""

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        artwork
                        titleBlock
                        volumeControls
                        transportControls
                        if isSingleSoundMode {
                            otherSoundsCarousel
                        }
                        footerActions
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        playerPresentation.isFullPlayerPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.text)
                    }
                    .accessibilityLabel("Minimize player")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        audio.stop()
                        playerPresentation.isFullPlayerPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.text)
                    }
                    .accessibilityLabel("Stop and close player")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isTimerSheetPresented) { TimerSheetView() }
        .sheet(isPresented: $isAddSoundSheetPresented) {
            AddSoundToMixSheet(excluding: Set(audio.layers.map(\.soundId))) { soundId in
                isAddSoundSheetPresented = false
                // Re-checked here too: the engine alone would refuse silently.
                SuperwallService.shared.gate(.mixer, parameters: ["source": "player"]) {
                    audio.addLayer(soundId: soundId)
                }
            }
        }
        .alert("Save mix", isPresented: $isSaveMixAlertPresented) {
            TextField("Mix name", text: $mixNameDraft)
            Button("Save") {
                SuperwallService.shared.gate(.mixer, parameters: ["source": "player"]) {
                    _ = prefs.saveMix(name: mixNameDraft, layers: audio.layers)
                    mixNameDraft = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var artwork: some View {
        Group {
            if let name = primaryArtworkName, UIImage(named: name) != nil {
                Image(name).resizable().scaledToFill()
            } else {
                palette.lilac
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(palette.outline, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var primaryArtworkName: String? {
        if let soundscape = BiblicalSoundscapeCatalog.soundscape(forMixID: audio.activeMix?.id) {
            return soundscape.artworkName
        }
        return audio.activeSoundId ?? audio.layers.first?.soundId
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(audio.displayTitle)
                .font(.essenceTitleLarge)
                .foregroundStyle(palette.text)
            if audio.layers.count > 1 {
                Text("\(audio.layers.count) sounds mixed")
                    .font(.essenceBodySmall)
                    .foregroundStyle(palette.secondaryText)
            }
            if let remaining = audio.timerRemaining {
                Text(Self.formattedRemaining(remaining))
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.accent)
                    .accessibilityLabel("Sleep timer: \(Self.formattedRemaining(remaining)) remaining")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private var volumeControls: some View {
        VStack(spacing: 16) {
            if audio.layers.count > 1 {
                ForEach(audio.layers) { layer in
                    HStack {
                        Text(soundTitle(layer.soundId))
                            .font(.essenceBodyMedium)
                            .foregroundStyle(palette.text)
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)
                        Slider(value: Binding(
                            get: { layer.volume },
                            set: { audio.setLayerVolume(soundId: layer.soundId, volume: $0) }
                        ))
                        .tint(palette.accent)
                        .accessibilityLabel("\(soundTitle(layer.soundId)) volume")
                        Button {
                            audio.removeLayer(soundId: layer.soundId)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(palette.secondaryText)
                        }
                        .accessibilityLabel("Remove \(soundTitle(layer.soundId)) from mix")
                    }
                }
            }
            HStack {
                Image(systemName: "speaker.wave.1")
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
                Slider(value: $audio.masterVolume, in: 0...1)
                    .tint(palette.accent)
                    .accessibilityLabel("Master volume")
                Image(systemName: "speaker.wave.3")
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
        }
    }

    private var isSingleSoundMode: Bool { audio.activeSoundId != nil && audio.layers.count == 1 }

    private var transportControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                if isSingleSoundMode {
                    Button {
                        audio.playAdjacentSound(offset: -1)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(palette.text)
                    }
                    .accessibilityLabel("Previous sound")
                }

                Button {
                    audio.togglePlayPause()
                } label: {
                    Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(palette.accent)
                }
                .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")

                if isSingleSoundMode {
                    Button {
                        audio.playAdjacentSound(offset: 1)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(palette.text)
                    }
                    .accessibilityLabel("Next sound")
                }
            }

            HStack(spacing: 32) {
                Button {
                    isTimerSheetPresented = true
                } label: {
                    Image(systemName: audio.timerDeadline != nil ? "clock.fill" : "clock")
                        .font(.title2)
                        .foregroundStyle(audio.timerDeadline != nil ? palette.accent : palette.text)
                }
                .accessibilityLabel("Sleep timer")

                Spacer()

                if let soundId = audio.activeSoundId, audio.layers.count == 1 {
                    Button {
                        prefs.toggleFavoriteSound(soundId)
                    } label: {
                        Image(systemName: prefs.isFavoriteSound(soundId) ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                    }
                    .accessibilityLabel(prefs.isFavoriteSound(soundId) ? "Remove from favorites" : "Add to favorites")
                } else {
                    Button {
                        isSaveMixAlertPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                            .foregroundStyle(palette.text)
                    }
                    .accessibilityLabel("Save mix")
                }
            }
        }
    }

    /// Horizontal "switch to a different sound" picker, shown only in single-sound mode —
    /// mirrors the Android player's `LazyRow` of other sounds below the volume slider.
    private var otherSoundsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other sounds")
                .font(.essenceTitleMedium)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(SoundCatalog.all.filter { $0.id != audio.activeSoundId }) { sound in
                        Button {
                            SuperwallService.shared.gate(
                                .sound(id: sound.id),
                                parameters: ["sound_id": sound.id]
                            ) {
                                audio.play(soundId: sound.id)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Group {
                                    if UIImage(named: sound.id) != nil {
                                        Image(sound.id).resizable().scaledToFill()
                                    } else {
                                        palette.lilac
                                    }
                                }
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                                .premiumLockOverlay(for: .sound(id: sound.id), padding: 0)

                                Text(soundTitle(sound.id))
                                    .font(.essenceBodySmall)
                                    .foregroundStyle(palette.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 85)
                    }
                }
            }
        }
    }

    private var footerActions: some View {
        Group {
            if audio.isActive, audio.layers.count < MixRules.maxLayers {
                Button {
                    SuperwallService.shared.gate(.mixer, parameters: ["source": "player"]) {
                        isAddSoundSheetPresented = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Label("Add another sound", systemImage: "plus.circle")
                        PremiumLockBadge(feature: .mixer)
                    }
                        .font(.essenceLabelLarge)
                }
                .foregroundStyle(palette.accent)
            }
        }
    }

    private func soundTitle(_ id: String) -> String {
        guard let sound = SoundCatalog.sound(id: id) else { return id }
        return AppLanguage.localized(sound.titleKey, defaultValue: id)
    }

    private static func formattedRemaining(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ZenSoundsTheme { PlayerView() }
}
