import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var navigation: NavigationModel
    @StateObject private var viewModel = DailyWordViewModel()
    @Environment(\.essencePalette) private var palette
    @State private var isSettingsPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                brand
                DailyWordCard(
                    state: viewModel.state,
                    onShuffle: viewModel.shuffle,
                    onExplore: {
                        if let reading = viewModel.state.reading {
                            navigation.openBible(bookCode: reading.book, chapter: reading.chapter, focusVerse: reading.verse)
                        }
                    }
                )
            }
            .padding()
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $isSettingsPresented) { SettingsView() }
        .task { viewModel.refresh() }
        .navigationDestination(for: BibleRoute.self) { route in
            BibleRouteDestination(route: route, language: viewModel.language)
        }
    }

    private var brand: some View {
        HStack(spacing: 0) {
            Text("Zen").font(.essenceTitleLarge).foregroundStyle(palette.text)
            Text("Sounds").font(.essenceTitleLarge).foregroundStyle(palette.accent)
        }
    }
}
