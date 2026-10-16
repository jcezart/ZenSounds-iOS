import SwiftUI

/// Search tab. Phase 1 keeps the previous screens reachable from here (Favorites and the full Sounds
/// library); recents, favorites preview and search arrive in phase 6.
struct SearchView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        List {
            Section(AppLanguage.localized("Explore", defaultValue: "Explore")) {
                NavigationLink(value: SearchRoute.favorites) {
                    Label(AppLanguage.localized("Favorites", defaultValue: "Favorites"), systemImage: "heart")
                }
                NavigationLink(value: SoundsRoute.library) {
                    Label(AppLanguage.localized("Sounds", defaultValue: "Sounds"), systemImage: "waveform")
                }
            }
        }
        .navigationTitle(AppLanguage.localized("Search", defaultValue: "Search"))
        .navigationDestination(for: SearchRoute.self) { route in
            switch route {
            case .favorites:
                FavoritesView()
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .ambientMiniPlayer(.whenActive)
    }
}
