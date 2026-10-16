import SwiftUI

@main
struct ZenSoundsApp: App {
    @StateObject private var languageStore = AppLanguageStore.shared
    private let superwall = SuperwallService.shared

    init() {
        superwall.configure(language: AppLanguageStore.shared.selection)
    }

    var body: some Scene {
        WindowGroup {
            ZenSoundsTheme {
                AppLaunchView()
            }
            .environment(\.locale, languageStore.selection.locale)
            .onOpenURL(perform: handleIncomingURL)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                handleIncomingURL(url)
            }
            .onChange(of: languageStore.selection) {
                superwall.updateUserProperties(language: languageStore.selection)
                AudioEngine.shared.languageDidChange()
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        OnboardingState.shared.suppressForCurrentLaunch()
        NotificationCenter.default.post(name: .oranteDeepLinkReceived, object: nil)
        if PlusDeepLink.matches(url) {
            superwall.gate(.widgetTheme(id: "widget"), parameters: ["source": "widget"]) {}
        } else if BibleDeepLink.parse(url) != nil {
            DeepLinkHandler.handle(url)
        } else if !superwall.handleDeepLink(url) {
            DeepLinkHandler.handle(url)
        }
    }
}

private struct AppLaunchView: View {
    @State private var isReady = false
    @State private var isOnboardingPresented = false
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
                        .accessibilityLabel("Loading Orante")
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
            isOnboardingPresented = OnboardingState.shared.shouldPresent
        }
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView {
                OnboardingState.shared.markSeen()
                isOnboardingPresented = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .oranteDeepLinkReceived)) { _ in
            isOnboardingPresented = false
        }
    }
}
