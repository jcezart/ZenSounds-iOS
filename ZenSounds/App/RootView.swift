import SwiftUI

struct RootView: View {
    @ObservedObject private var navigation = NavigationModel.shared
    @ObservedObject private var playerPresentation = PlayerPresentation.shared
    @ObservedObject private var audio = AudioEngine.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        TabView(selection: navigation.selectionBinding) {
            NavigationStack(path: $navigation.homePath) {
                HomeView()
            }
            .withCompactPlayer()
            .tabItem { Label("Home", systemImage: AppTab.home.systemImage) }
            .tag(AppTab.home)

            NavigationStack(path: $navigation.biblePath) {
                BibleBooksView()
            }
            .withCompactPlayer()
            .tabItem { Label("Bible", systemImage: AppTab.bible.systemImage) }
            .tag(AppTab.bible)

            NavigationStack(path: $navigation.soundsPath) {
                SoundsLibraryView()
            }
            .withCompactPlayer()
            .tabItem { Label("Sounds", systemImage: AppTab.sounds.systemImage) }
            .tag(AppTab.sounds)

            NavigationStack(path: $navigation.favoritesPath) {
                FavoritesView()
            }
            .withCompactPlayer()
            .tabItem { Label("Favorites", systemImage: AppTab.favorites.systemImage) }
            .tag(AppTab.favorites)
        }
        .tint(palette.accent)
        .fullScreenCover(isPresented: $playerPresentation.isFullPlayerPresented) {
            PlayerView()
        }
        .environmentObject(navigation)
    }
}

/// Reserves space for the compact mini player above each tab's own content via
/// `safeAreaInset`, applied per-tab rather than on the `TabView` itself. Attaching it to the
/// `TabView` directly renders the mini player in front of the native tab bar chrome and steals
/// its touches — every tab button becomes unreachable while something is playing. Per-tab
/// placement keeps the system tab bar as the topmost hit-testable element in that strip.
private struct CompactPlayerInset: ViewModifier {
    @ObservedObject var audio = AudioEngine.shared
    @ObservedObject var playerPresentation = PlayerPresentation.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if audio.isActive && !playerPresentation.isFullPlayerPresented {
                CompactPlayerView { playerPresentation.isFullPlayerPresented = true }
            }
        }
    }
}

private extension View {
    func withCompactPlayer() -> some View {
        modifier(CompactPlayerInset())
    }
}

#Preview {
    ZenSoundsTheme { RootView() }
}

#Preview("Dark") {
    ZenSoundsTheme { RootView() }
        .preferredColorScheme(.dark)
}
