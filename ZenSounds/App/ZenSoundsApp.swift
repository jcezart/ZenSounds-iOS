import SwiftUI

@main
struct ZenSoundsApp: App {
    @StateObject private var languageStore = AppLanguageStore.shared

    var body: some Scene {
        WindowGroup {
            ZenSoundsTheme {
                AppLaunchView()
            }
            .environment(\.locale, languageStore.selection.locale)
            .onOpenURL { url in
                DeepLinkHandler.handle(url)
            }
        }
    }
}

private struct AppLaunchView: View {
    @State private var isReady = false
    @Environment(\.essencePalette) private var palette

    var body: some View {
        ZStack {
            if isReady {
                RootView()
            } else {
                VStack(spacing: 20) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 136, height: 136)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                    ProgressView()
                        .tint(palette.accent)
                        .controlSize(.small)
                        .accessibilityLabel("Loading ZenSounds")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background)
            }
        }
        .task {
            guard !isReady else { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(180))
            isReady = true
        }
    }
}
