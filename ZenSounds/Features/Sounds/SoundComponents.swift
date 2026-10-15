import SwiftUI
import UIKit

struct BiblicalSoundscapeCard: View {
    let soundscape: BiblicalSoundscape
    let onPlay: () -> Void
    let onOpenPassage: () -> Void

    @Environment(\.essencePalette) private var palette
    @ObservedObject private var superwall = SuperwallService.shared

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
                if superwall.premiumGate.shouldShowBadge(for: .soundscape(id: soundscape.id)) {
                    OrantePlusBadge()
                }
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
    let sound: SoundItem
    let onTap: () -> Void

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @ObservedObject private var superwall = SuperwallService.shared
    @Environment(\.essencePalette) private var palette

    private var title: String {
        AppLanguage.localized(sound.titleKey, defaultValue: sound.id)
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
                    if superwall.premiumGate.shouldShowBadge(for: .sound(id: sound.id)) {
                        OrantePlusBadge()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Play sound")

            Button {
                prefs.toggleFavoriteSound(sound.id)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.secondaryText.opacity(0.72))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(minHeight: 82)
        .soundLibraryCard()
    }
}

struct MixRow: View {
    let mix: SavedMix
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.essencePalette) private var palette
    @ObservedObject private var superwall = SuperwallService.shared

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
                    if superwall.shouldShowPremiumBadges {
                        OrantePlusBadge()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mix.name)
            .accessibilityValue(layerSummary)
            .accessibilityHint("Play mix")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete mix \(mix.name)")

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
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
                AppLanguage.localized($0.titleKey, defaultValue: $0.id)
            }
        }
        .joined(separator: " · ")
    }
}

struct OrantePlusBadge: View {
    @Environment(\.essencePalette) private var palette

    var body: some View {
        Text("+")
            .font(.essenceLabelLarge)
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(palette.accent.opacity(0.12), in: Capsule())
            .accessibilityLabel("Requires Orante+")
    }
}

private struct SoundArtwork: View {
    let soundID: String

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
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
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
