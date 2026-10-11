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
                        ThinProgressView(progress: progress)
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

    private var progress: Double {
        guard let remaining = audio.timerRemaining, let minutes = audio.timerDurationMinutes, minutes > 0 else { return 0 }
        let total = Double(minutes * 60)
        return 1 - (remaining / total)
    }

    private var artwork: some View {
        Group {
            if let id = audio.activeSoundId ?? audio.layers.first?.soundId, UIImage(named: id) != nil {
                Image(id).resizable().scaledToFill()
            } else {
                palette.lilac
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ThinProgressView: View {
    let progress: Double
    @Environment(\.essencePalette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule().fill(palette.accent).frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 3)
    }
}
