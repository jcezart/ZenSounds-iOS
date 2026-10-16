import SwiftUI

/// Search → Explore → Prayers: the Rosary prayers already bundled with the app, in praying order.
struct PrayersView: View {
    let language: BibleLanguage
    @EnvironmentObject private var navigation: NavigationModel
    @Environment(\.essencePalette) private var palette

    private var prayers: [(id: String, kind: RosaryPrayerKind)] {
        RosaryRepository.shared.prayers.compactMap { prayer in
            RosaryPrayerKind(rawValue: prayer.id).map { (prayer.id, $0) }
        }
    }

    var body: some View {
        ScrollView {
            RowCard(items: prayers.map(\.id)) { id in
                ShortcutRow(
                    systemImage: "hands.and.sparkles",
                    title: Text(verbatim: RosaryPrayerKind(rawValue: id).map { RosaryLabels.prayerName($0, language: language) } ?? id),
                    subtitle: nil,
                    action: { navigation.push(SearchRoute.prayer(id: id)) }
                )
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xs)
        }
        .background(palette.background)
        .navigationTitle(Text("Prayers"))
        .ambientMiniPlayer(.whenActive)
    }
}

/// Full text of one prayer, in serif, in the Rosary's content language.
struct PrayerDetailView: View {
    let prayerID: String
    let language: BibleLanguage
    @Environment(\.essencePalette) private var palette

    private var prayer: RosaryPrayer? { RosaryRepository.shared.prayers.first { $0.id == prayerID } }
    private var title: String {
        RosaryPrayerKind(rawValue: prayerID).map { RosaryLabels.prayerName($0, language: language) } ?? prayerID
    }
    private var text: String {
        guard let prayer else { return "" }
        return language == .pt ? prayer.pt : prayer.en
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(.scriptureTitle)
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text(text)
                    .font(.scriptureBody)
                    .lineSpacing(6)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
        }
        .background(palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !text.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: "\(title)\n\n\(text)\n\n— Orante") {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Text("Share"))
                }
            }
        }
        .ambientMiniPlayer(.whenActive)
    }
}

#Preview {
    ZenSoundsTheme {
        NavigationStack {
            PrayerDetailView(prayerID: "hailHolyQueen", language: .pt)
        }
    }
}
