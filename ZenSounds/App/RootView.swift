import SwiftUI

struct RootView: View {
    @ObservedObject private var navigation = NavigationModel.shared
    @ObservedObject private var playerPresentation = PlayerPresentation.shared
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var narration = BibleNarrationService.shared
    @ObservedObject private var trialReminder = TrialReminderService.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        TabView(selection: navigation.selectionBinding) {
            Tab("Today", systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack(path: $navigation.homePath) {
                    HomeView()
                        .soundsDestinations()
                }
                .withCompactPlayer()
            }

            Tab("Bible", systemImage: AppTab.bible.systemImage, value: AppTab.bible) {
                NavigationStack(path: $navigation.biblePath) {
                    BibleBooksView()
                        .soundsDestinations()
                }
                .withCompactPlayer()
            }

            Tab("Rosary", systemImage: AppTab.rosary.systemImage, value: AppTab.rosary) {
                NavigationStack(path: $navigation.rosaryPath) {
                    RosaryView()
                        .soundsDestinations()
                }
                .withCompactPlayer()
            }

            // Search role: pinned at the trailing edge, and on iOS 26 shown as the separate glass search tab.
            Tab("Search", systemImage: AppTab.search.systemImage, value: AppTab.search, role: .search) {
                NavigationStack(path: $navigation.searchPath) {
                    SearchView()
                        .soundsDestinations()
                }
                .withCompactPlayer()
            }
        }
        .tint(palette.accent)
        .fullScreenCover(isPresented: $playerPresentation.isFullPlayerPresented) {
            PlayerView()
        }
        .environmentObject(navigation)
        .alert(
            "Narration unavailable",
            isPresented: Binding(
                get: { narration.errorMessage != nil },
                set: { if !$0 { narration.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { narration.clearError() }
        } message: {
            Text(narration.errorMessage ?? "")
        }
        .alert(
            "Audio unavailable",
            isPresented: Binding(
                get: { audio.playbackError != nil },
                set: { if !$0 { audio.clearPlaybackError() } }
            )
        ) {
            Button("OK", role: .cancel) { audio.clearPlaybackError() }
        } message: {
            Text(audio.playbackError ?? "Please try again.")
        }
        .alert("Trial reminder", isPresented: $trialReminder.shouldExplainPermission) {
            Button("Not now", role: .cancel) {}
            Button("Allow reminders") {
                Task { await trialReminder.requestAndSchedule() }
            }
        } message: {
            Text("We'll notify you 2 days before your Orante+ trial ends.")
        }
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
