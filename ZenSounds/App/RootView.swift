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
            }

            Tab("Bible", systemImage: AppTab.bible.systemImage, value: AppTab.bible) {
                NavigationStack(path: $navigation.biblePath) {
                    BibleBooksView()
                        .soundsDestinations()
                }
            }

            Tab("Rosary", systemImage: AppTab.rosary.systemImage, value: AppTab.rosary) {
                NavigationStack(path: $navigation.rosaryPath) {
                    RosaryView()
                        .soundsDestinations()
                }
            }

            // Search role: pinned at the trailing edge, and on iOS 26 shown as the separate glass search tab.
            Tab("Search", systemImage: AppTab.search.systemImage, value: AppTab.search, role: .search) {
                NavigationStack(path: $navigation.searchPath) {
                    SearchView()
                        .soundsDestinations()
                }
            }
        }
        .tint(palette.accent)
        .sheet(
            isPresented: $playerPresentation.isAmbientSheetPresented,
            onDismiss: { playerPresentation.runAfterAmbientSheetDismiss() }
        ) {
            AmbientSoundSheet()
        }
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

#Preview {
    ZenSoundsTheme { RootView() }
}

#Preview("Dark") {
    ZenSoundsTheme { RootView() }
        .preferredColorScheme(.dark)
}
