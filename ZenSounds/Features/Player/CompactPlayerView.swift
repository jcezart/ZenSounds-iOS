import SwiftUI
import UIKit

/// Persistent mini player shown above the tab bar whenever something is playing and the full
/// player isn't on screen. Pinned via `.safeAreaInset(edge: .bottom)` on the root `TabView` so
/// it never overlaps tab content or controls.
struct CompactPlayerView: View {
    let onExpand: () -> Void

    @ObservedObject private var audio = AudioEngine.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    artwork
                    VStack(alignment: .leading, spacing: 4) {
                        Text(audio.displayTitle)
                            .font(.essenceLabelLarge)
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open player: \(audio.displayTitle)")

            Spacer(minLength: 8)

            Button {
                audio.togglePlayPause()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(palette.text)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")

            Button {
                audio.stop()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Stop and close player")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(palette.surface)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(palette.outline), alignment: .top)
    }

    private var artwork: some View {
        Group {
            if let id = artworkName, UIImage(named: id) != nil {
                Image(id).resizable().scaledToFill()
            } else {
                palette.lilac
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var artworkName: String? {
        if let soundscape = BiblicalSoundscapeCatalog.soundscape(forMixID: audio.activeMix?.id) {
            return soundscape.artworkName
        }
        return audio.activeSoundId ?? audio.layers.first?.soundId
    }
}
