import SwiftUI
import UIKit

struct SoundCard: View {
    let sound: SoundItem
    let onTap: () -> Void

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, onTap)

            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top)
                .allowsHitTesting(false)

            HStack {
                Text(title)
                    .font(.essenceLabelLarge)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .accessibilityHidden(true)
                Spacer()
                Button {
                    prefs.toggleFavoriteSound(sound.id)
                } label: {
                    Image(systemName: prefs.isFavoriteSound(sound.id) ? "heart.fill" : "heart")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(prefs.isFavoriteSound(sound.id) ? "Remove \(title) from favorites" : "Add \(title) to favorites")
            }
            .padding(10)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var title: String { NSLocalizedString(sound.titleKey, value: sound.id, comment: "") }

    private var background: some View {
        Group {
            if UIImage(named: sound.id) != nil {
                Image(sound.id).resizable().scaledToFill()
            } else {
                palette.lilac
            }
        }
    }
}

struct MixRow: View {
    let mix: SavedMix
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(palette.accent)
                .frame(width: 36, height: 36)
                .background(palette.lilac)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(mix.name).font(.essenceBodyLarge).foregroundStyle(palette.text)
                Text(layerSummary).font(.essenceBodySmall).foregroundStyle(palette.secondaryText).lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onTap)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(palette.secondaryText)
            }
            .accessibilityLabel("Delete mix \(mix.name)")
        }
        .padding(12)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var layerSummary: String {
        mix.layers.compactMap { layer in
            SoundCatalog.sound(id: layer.soundId).map { NSLocalizedString($0.titleKey, value: $0.id, comment: "") }
        }.joined(separator: ", ")
    }
}
