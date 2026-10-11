import SwiftUI
import Combine

/// Owns one `NavigationPath` per tab so each tab keeps its own back-stack independently.
/// Reselecting the already-active tab resets that tab's stack to its root — e.g. opening a
/// sound from Favorites and then tapping the Favorites tab again returns to the favorites
/// list instead of leaving the user stuck on the detail screen.
@MainActor
final class NavigationModel: ObservableObject {
    static let shared = NavigationModel()

    @Published var selectedTab: AppTab = .home
    @Published var homePath = NavigationPath()
    @Published var biblePath = NavigationPath()
    @Published var soundsPath = NavigationPath()
    @Published var favoritesPath = NavigationPath()

    var selectionBinding: Binding<AppTab> {
        Binding(
            get: { self.selectedTab },
            set: { newValue in
                if newValue == self.selectedTab {
                    self.resetPath(for: newValue)
                }
                self.selectedTab = newValue
            }
        )
    }

    func resetPath(for tab: AppTab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .bible: biblePath = NavigationPath()
        case .sounds: soundsPath = NavigationPath()
        case .favorites: favoritesPath = NavigationPath()
        }
    }

    func openBible(bookCode: String, chapter: Int, focusVerse: Int? = nil) {
        selectedTab = .bible
        biblePath = NavigationPath()
        biblePath.append(BibleRoute.verses(bookCode: bookCode, chapter: chapter, focusVerse: focusVerse))
    }
}

@MainActor
final class PlayerPresentation: ObservableObject {
    static let shared = PlayerPresentation()
    @Published var isFullPlayerPresented = false
}
