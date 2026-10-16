import SwiftUI

/// "Ambient sound" mini-player. While something plays it shows that sound with play/pause; when idle it
/// shows the last sound played (Rain the first time) ready to start. The adjust button opens the
/// ambient sheet; tapping the title opens the full player (timer, fade, mix) when audio is active.
struct AmbientMiniPlayer: View {
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var preferences = UserPreferencesStore.shared
    @ObservedObject private var presentation = PlayerPresentation.shared
    @Environment(\.essencePalette) private var palette

    private var idleItem: AmbientItem { preferences.resolvedLastAmbient }

    private var title: String {
        audio.isActive ? audio.displayTitle : AmbientPlayback.title(for: idleItem)
    }

    private var symbol: String {
        if audio.isActive {
            return AmbientPlayback.currentItem().map { AmbientPlayback.symbol(for: $0) } ?? "slider.horizontal.3"
        }
        return AmbientPlayback.symbol(for: idleItem)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: openDetails) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(palette.text)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ambient sound")
                            .font(.essenceLabelMedium)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                        Text(title)
                            .font(.essenceBodyMedium)
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Spacing.xs)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(audio.isActive ? Text("Opens the player") : Text("Opens ambient sound options"))

            if !audio.isActive {
                PremiumLockBadge(feature: idleItem.premiumFeature)
            }

            Button(action: playPause) {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 40, height: 40)
                    .background(palette.surfaceElevated, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audio.isPlaying ? Text("Pause") : Text("Play"))

            Button {
                presentation.isAmbientSheetPresented = true
            } label: {
                Image(systemName: "slider.vertical.3")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 40, height: 40)
                    .background(palette.surfaceElevated, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Ambient sound options"))
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .ambientGlass(palette: palette)
        .contextMenu {
            if audio.isActive {
                Button(role: .destructive) { audio.stop() } label: {
                    Label("Stop and close player", systemImage: "xmark")
                }
            }
        }
    }

    private func playPause() {
        if audio.isActive {
            audio.togglePlayPause()
        } else {
            AmbientPlayback.start(idleItem)
        }
    }

    private func openDetails() {
        if audio.isActive {
            presentation.isFullPlayerPresented = true
        } else {
            presentation.isAmbientSheetPresented = true
        }
    }
}

private extension View {
    /// Liquid Glass on iOS 26+, translucent material on iOS 18.
    @ViewBuilder
    func ambientGlass(palette: EssencePalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(palette.outline.opacity(0.6), lineWidth: 0.5))
        }
    }
}

/// Pins the mini-player above the tab bar on screens that want it (Reading, Rosary always; lists only
/// while audio is active). Today places it inline instead.
private struct AmbientMiniPlayerInset: ViewModifier {
    let visibility: AmbientMiniPlayerVisibility
    @ObservedObject private var audio = AudioEngine.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if visibility.isVisible(isAudioActive: audio.isActive) {
                AmbientMiniPlayer()
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xxs)
            }
        }
    }
}

extension View {
    func ambientMiniPlayer(_ visibility: AmbientMiniPlayerVisibility) -> some View {
        modifier(AmbientMiniPlayerInset(visibility: visibility))
    }
}
