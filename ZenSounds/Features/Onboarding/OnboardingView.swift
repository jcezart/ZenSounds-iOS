import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.essencePalette) private var palette
    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .foregroundStyle(palette.secondaryText)
            }

            TabView(selection: $page) {
                OnboardingPage(
                    symbol: "book.closed.fill",
                    title: "The Bible, always with you",
                    message: "Read the complete Bible offline and begin each day with the Word of the Day."
                ).tag(0)
                OnboardingPage(
                    symbol: "circle.hexagongrid.fill",
                    title: "Prayer and peaceful soundscapes",
                    message: "Pray the Rosary and accompany your quiet moments with biblical soundscapes."
                ).tag(1)
                OnboardingPage(
                    symbol: "speaker.wave.2.fill",
                    title: "Listen to the Word and pray peacefully",
                    message: "Orante+ adds complete narration, guided prayer, mixes, and more sounds."
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == 2 ? "Start" : "Continue") {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    SuperwallService.shared.registerNonGated(
                        placement: SuperwallService.Placement.onboardingEnd
                    )
                    onFinish()
                }
            }
            .font(.essenceLabelLarge)
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(palette.onAccent)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(24)
        .background(palette.background)
    }
}

private struct OnboardingPage: View {
    let symbol: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    @Environment(\.essencePalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: symbolSize))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.essenceHeadlineMedium)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.text)
            Text(message)
                .font(.essenceBodyLarge)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.secondaryText)
            Spacer()
        }
    }
}
