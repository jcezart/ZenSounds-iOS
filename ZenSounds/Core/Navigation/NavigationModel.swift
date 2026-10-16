import SwiftUI
import Combine

/// Owns one `NavigationPath` per tab so each tab keeps its own back-stack independently.
/// Reselecting the already-active tab resets that tab's stack to its root — e.g. opening a
/// chapter from Search and then tapping the Search tab again returns to its root instead of
/// leaving the user stuck on the detail screen.
@MainActor
final class NavigationModel: ObservableObject {
    static let shared = NavigationModel()

    @Published var selectedTab: AppTab = .home
    @Published var homePath = NavigationPath()
    @Published var biblePath = NavigationPath()
    @Published var rosaryPath = NavigationPath()
    @Published var searchPath = NavigationPath()

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
        case .rosary: rosaryPath = NavigationPath()
        case .search: searchPath = NavigationPath()
        }
    }

    /// Pushes a route onto the stack of the tab that is currently visible.
    func push<Route: Hashable>(_ route: Route) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .bible: biblePath.append(route)
        case .rosary: rosaryPath.append(route)
        case .search: searchPath.append(route)
        }
    }

    func openBible(bookCode: String, chapter: Int, focusVerse: Int? = nil) {
        selectedTab = .bible
        biblePath = NavigationPath()
        biblePath.append(BibleRoute.verses(bookCode: bookCode, chapter: chapter, focusVerse: focusVerse))
    }

    /// Set of mysteries requested from outside the Rosary tab (Search); `RosaryView` consumes it.
    @Published var pendingRosarySet: RosaryMysterySetID?

    func openRosary(set: RosaryMysterySetID? = nil) {
        pendingRosarySet = set
        selectedTab = .rosary
    }

    /// Opens the full sound library inside Search (Search → Explore → Sounds).
    func openSoundsLibrary() {
        selectedTab = .search
        searchPath = NavigationPath()
        searchPath.append(SoundsRoute.library)
    }
}

@MainActor
final class PlayerPresentation: ObservableObject {
    static let shared = PlayerPresentation()
    @Published var isFullPlayerPresented = false
    /// The "Ambient sound" sheet, presented from the root so every tab can open it.
    @Published var isAmbientSheetPresented = false
    /// Navigation requested from inside the ambient sheet, run once the sheet has finished dismissing.
    var afterAmbientSheetDismiss: (() -> Void)?

    /// Closes the ambient sheet and then performs `action` (open the player, the library, the mix editor).
    func dismissAmbientSheet(then action: @escaping () -> Void) {
        afterAmbientSheetDismiss = action
        isAmbientSheetPresented = false
    }

    func runAfterAmbientSheetDismiss() {
        let action = afterAmbientSheetDismiss
        afterAmbientSheetDismiss = nil
        action?()
    }
}
