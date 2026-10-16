import SwiftUI
import UIKit

struct BiblicalSoundscapeCard: View {
    /// Re-renders titles resolved with `AppLanguage.localized` when the in-app language changes.
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let soundscape: BiblicalSoundscape
    let onPlay: () -> Void
    let onOpenPassage: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(soundscape.artworkName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 190)

            VStack(alignment: .leading, spacing: 6) {
                Text(soundscape.localizedTitle)
                    .font(.essenceTitleLarge)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Button(action: onOpenPassage) {
                    Label(soundscape.localizedReference, systemImage: "book.closed")
                        .font(.essenceBodySmall)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityHint(AppLanguage.localized("soundscape_open_passage_hint", defaultValue: "Open the related Bible passage"))

                Button(action: onPlay) {
                    Label(
                        AppLanguage.localized("soundscape_play", defaultValue: "Play soundscape"),
                        systemImage: "play.fill"
                    )
                    .font(.essenceLabelLarge)
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(16)
        }
        .frame(height: 190)
        .premiumLockOverlay(for: .soundscape(id: soundscape.id), padding: 12)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: palette.accent.opacity(0.16), radius: 14, y: 7)
        .accessibilityElement(children: .contain)
    }
}

struct SoundRow: View {
    /// Re-renders titles resolved with `AppLanguage.localized` when the in-app language changes.
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let sound: SoundItem
    let onTap: () -> Void

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    private var title: String {
        sound.localizedTitle
    }

    private var isFavorite: Bool {
        prefs.isFavoriteSound(sound.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    SoundArtwork(soundID: sound.id)

                    Text(title)
                        .font(.essenceTitleMedium)
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)
                    PremiumLockBadge(feature: .sound(id: sound.id))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Play sound")

            Button {
                prefs.toggleFavoriteSound(sound.id)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(palette.accent)
                    .symbolEffect(.bounce, value: isFavorite)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isFavorite
                    ? "Remove \(title) from favorites"
                    : "Add \(title) to favorites"
            )

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.secondaryText.opacity(0.72))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(minHeight: 82)
        .soundLibraryCard()
    }
}

struct MixRow: View {
    /// Re-renders titles resolved with `AppLanguage.localized` when the in-app language changes.
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let mix: SavedMix
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    MixArtwork(soundID: mix.layers.first?.soundId)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mix.name)
                            .font(.essenceTitleMedium)
                            .foregroundStyle(palette.text)
                            .lineLimit(1)

                        if !layerSummary.isEmpty {
                            Text(layerSummary)
                                .font(.essenceBodySmall)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)
                    PremiumLockBadge(feature: .savedMix)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mix.name)
            .accessibilityValue(layerSummary)
            .accessibilityHint("Play mix")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete mix \(mix.name)")

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.secondaryText.opacity(0.72))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(minHeight: 82)
        .soundLibraryCard()
    }

    private var layerSummary: String {
        mix.layers.compactMap { layer in
            SoundCatalog.sound(id: layer.soundId).map {
                $0.localizedTitle
            }
        }
        .joined(separator: " · ")
    }
}

struct SoundArtwork: View {
    let soundID: String
    var size: CGFloat = 62

    var body: some View {
        Group {
            if UIImage(named: soundID) != nil {
                Image(soundID)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.blue.opacity(0.72), .green.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: artworkSymbol)
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
            .accessibilityHidden(true)
    }

    private var artworkSymbol: String {
        switch soundID {
        case "GalileeWaves": return "water.waves"
        case "MeadowSheep": return "cloud.fill"
        case "OliveGrove": return "leaf.fill"
        case "MorningBirds": return "bird.fill"
        case "NightCrickets": return "moon.stars.fill"
        default: return "waveform"
        }
    }
}

private struct MixArtwork: View {
    let soundID: String?

    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack {
            if let soundID {
                SoundArtwork(soundID: soundID)
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(palette.accent.opacity(0.12))
                    .frame(width: 62, height: 62)

                Image(systemName: "waveform")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(palette.accent)
            }
        }
    }
}

private struct SoundLibraryCardModifier: ViewModifier {
    @Environment(\.essencePalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.outline.opacity(colorScheme == .dark ? 0.65 : 0.45), lineWidth: 0.5)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : 0.055),
                radius: colorScheme == .dark ? 10 : 14,
                y: colorScheme == .dark ? 5 : 7
            )
    }
}

private extension View {
    func soundLibraryCard() -> some View {
        modifier(SoundLibraryCardModifier())
    }
}
