import WidgetKit
import SwiftUI
import AppIntents

enum WidgetBackgroundTheme: String, AppEnum, Sendable {
    case terracotta
    case forest
    case midnight
    case plum
    case ocean

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Background color"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .terracotta: "Terracotta",
        .forest: "Forest",
        .midnight: "Midnight",
        .plum: "Plum",
        .ocean: "Ocean"
    ]

    static func resolved(_ selected: Self, hasPlus: Bool) -> Self {
        hasPlus ? selected : .terracotta
    }

    /// A paid color picked without Orante+: the widget falls back to Terracotta and says why.
    static func isLocked(_ selected: Self, hasPlus: Bool) -> Bool {
        selected != .terracotta && !hasPlus
    }

    /// Picker titles: non-subscribers see which colors belong to Orante+.
    func optionTitle(hasPlus: Bool) -> LocalizedStringResource {
        switch (self, hasPlus) {
        case (.terracotta, _): "Terracotta"
        case (.forest, true): "Forest"
        case (.forest, false): "Forest (Orante+)"
        case (.midnight, true): "Midnight"
        case (.midnight, false): "Midnight (Orante+)"
        case (.plum, true): "Plum"
        case (.plum, false): "Plum (Orante+)"
        case (.ocean, true): "Ocean"
        case (.ocean, false): "Ocean (Orante+)"
        }
    }
}

/// Mirror of the app's `plus_active` flag in the shared App Group (written by `SuperwallService`).
enum WidgetPlusStatus {
    static var isActive: Bool {
        UserDefaults(suiteName: WidgetDailyWordStore.appGroupID)?.bool(forKey: "plus_active") ?? false
    }
}

/// Keeps the parameter an `AppEnum` (existing configurations stay valid) while labelling paid colors.
struct WidgetBackgroundThemeOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<WidgetBackgroundTheme> {
        let hasPlus = WidgetPlusStatus.isActive
        let items = WidgetBackgroundTheme.allCases.map { theme in
            IntentItem(theme, title: theme.optionTitle(hasPlus: hasPlus))
        }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
    }

    func defaultResult() async -> WidgetBackgroundTheme? {
        .terracotta
    }
}

struct ZenSoundsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Customize Widget"
    static var description = IntentDescription("Choose the widget background color.")

    @Parameter(title: "Background color", default: .terracotta, optionsProvider: WidgetBackgroundThemeOptionsProvider())
    var backgroundTheme: WidgetBackgroundTheme
}

struct DailyWordEntry: TimelineEntry {
    let date: Date
    let reading: WidgetReadingRef
    let text: String
    let bookName: String
    let backgroundTheme: WidgetBackgroundTheme
    /// The user picked a paid color without Orante+ (shown as Terracotta with a badge).
    var isLockedColor = false

    var deepLinkURL: URL? {
        URL(string: "zensounds://chapter/\(reading.book)/\(reading.chapter)/\(reading.verse)")
    }

    /// Home Screen tap target: a locked color opens the Orante+ offer instead of the chapter.
    var homeScreenURL: URL? {
        isLockedColor ? URL(string: "zensounds://plus") : deepLinkURL
    }
}

struct DailyWordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DailyWordEntry {
        DailyWordEntry(
            date: Date(),
            reading: WidgetReadingRef(book: "PSA", chapter: 23, verse: 1),
            text: "O SENHOR é meu pastor, nada me faltará.",
            bookName: "Salmos",
            backgroundTheme: .terracotta
        )
    }

    func snapshot(for configuration: ZenSoundsWidgetConfigurationIntent, in context: Context) async -> DailyWordEntry {
        currentEntry(backgroundTheme: configuration.backgroundTheme)
    }

    func timeline(for configuration: ZenSoundsWidgetConfigurationIntent, in context: Context) async -> Timeline<DailyWordEntry> {
        let entry = currentEntry(backgroundTheme: configuration.backgroundTheme)
        // The word only changes at local midnight; ask the system to check back then. WidgetKit
        // treats this as a best-effort budget request, not a guaranteed exact-time refresh.
        let nextMidnight = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func currentEntry(backgroundTheme: WidgetBackgroundTheme) -> DailyWordEntry {
        let source = WidgetDataSource.shared
        let store = WidgetDailyWordStore()
        let ref = store.reference(for: Date(), readings: source.readings)
        let language = WidgetLanguage.preferred
        let reading = source.readings.first { $0.book == ref.book && $0.chapter == ref.chapter && $0.verse == ref.verse }
        let text = reading.map { source.text(for: $0, language: language) } ?? ""
        let bookName = source.book(code: ref.book).map { language == .pt ? $0.name_pt : $0.name_en } ?? ref.book
        let hasPlus = WidgetPlusStatus.isActive
        return DailyWordEntry(
            date: Date(),
            reading: ref,
            text: text,
            bookName: bookName,
            backgroundTheme: .resolved(backgroundTheme, hasPlus: hasPlus),
            isLockedColor: WidgetBackgroundTheme.isLocked(backgroundTheme, hasPlus: hasPlus)
        )
    }
}

struct ZenSoundsWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DailyWordEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallDailyWordView(entry: entry)
            case .accessoryRectangular:
                LockScreenRectangularView(entry: entry)
            case .accessoryInline:
                LockScreenInlineView(entry: entry)
            default:
                MediumDailyWordView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            if isAccessoryFamily {
                Color.clear
            } else {
                WidgetArtworkBackground(theme: entry.backgroundTheme)
            }
        }
    }

    private var isAccessoryFamily: Bool {
        switch family {
        case .accessoryRectangular, .accessoryInline:
            true
        default:
            false
        }
    }
}

struct SmallDailyWordView: View {
    let entry: DailyWordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("WORD OF THE DAY", systemImage: "leaf.fill")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.82))
            Text(entry.text)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(6)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Spacer(minLength: 2)
            Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            if entry.isLockedColor {
                PlusColorBadge()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.homeScreenURL)
    }
}

struct MediumDailyWordView: View {
    let entry: DailyWordEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("WORD OF THE DAY", systemImage: "leaf.fill")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                if entry.isLockedColor {
                    PlusColorBadge()
                }
                Button(intent: ShuffleDailyWordIntent()) {
                    Image(systemName: "shuffle")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show another verse")
            }
            Text(entry.text)
                .font(.system(size: family == .systemLarge ? 20 : 17, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(family == .systemLarge ? 10 : 5)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: family == .systemLarge ? .infinity : 250, alignment: .leading)
            Spacer(minLength: 2)
            Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(entry.homeScreenURL)
    }
}

/// Discreet note that the chosen color needs Orante+; the widget then shows Terracotta.
private struct PlusColorBadge: View {
    var body: some View {
        Label("Orante+ color", systemImage: "lock.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.18), in: Capsule())
    }
}

struct LockScreenRectangularView: View {
    let entry: DailyWordEntry

    var body: some View {
        ZStack(alignment: .trailing) {
            WidgetBotanicalArtwork(color: .white.opacity(0.22))
                .frame(width: 54)
                .offset(x: 6)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                    Text("ORANTE")
                        .tracking(0.7)
                }
                .font(.system(size: 7, weight: .bold))
                .opacity(0.72)

                Text(entry.text)
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)")
                    .font(.system(size: 8, weight: .bold))
                    .lineLimit(1)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .widgetURL(entry.deepLinkURL)
    }
}

struct LockScreenInlineView: View {
    let entry: DailyWordEntry

    var body: some View {
        Label("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)", systemImage: "leaf.fill")
            .foregroundStyle(.white)
            .widgetURL(entry.deepLinkURL)
    }
}

private struct WidgetArtworkBackground: View {
    let theme: WidgetBackgroundTheme

    var body: some View {
        ZStack(alignment: .trailing) {
            LinearGradient(
                colors: palette.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.glow.opacity(0.42))
                .frame(width: 190, height: 190)
                .blur(radius: 28)
                .offset(x: 54, y: -72)

            WidgetHillShape()
                .fill(palette.hill.opacity(0.38))
                .frame(height: 72)
                .frame(maxHeight: .infinity, alignment: .bottom)

            WidgetBotanicalArtwork(color: .white.opacity(0.15))
                .frame(width: 104)
                .padding(.trailing, 5)
                .padding(.vertical, 2)
        }
    }

    private var palette: WidgetArtworkPalette {
        switch theme {
        case .terracotta:
            WidgetArtworkPalette(
                gradient: [Color(red: 0.73, green: 0.32, blue: 0.23), Color(red: 0.45, green: 0.20, blue: 0.20)],
                glow: Color(red: 1.0, green: 0.77, blue: 0.54),
                hill: Color(red: 0.32, green: 0.15, blue: 0.18)
            )
        case .forest:
            WidgetArtworkPalette(
                gradient: [Color(red: 0.25, green: 0.43, blue: 0.32), Color(red: 0.10, green: 0.24, blue: 0.20)],
                glow: Color(red: 0.68, green: 0.76, blue: 0.48),
                hill: Color(red: 0.05, green: 0.16, blue: 0.13)
            )
        case .midnight:
            WidgetArtworkPalette(
                gradient: [Color(red: 0.20, green: 0.27, blue: 0.45), Color(red: 0.08, green: 0.11, blue: 0.25)],
                glow: Color(red: 0.56, green: 0.70, blue: 0.94),
                hill: Color(red: 0.05, green: 0.07, blue: 0.18)
            )
        case .plum:
            WidgetArtworkPalette(
                gradient: [Color(red: 0.48, green: 0.27, blue: 0.43), Color(red: 0.25, green: 0.12, blue: 0.27)],
                glow: Color(red: 0.91, green: 0.63, blue: 0.75),
                hill: Color(red: 0.18, green: 0.08, blue: 0.20)
            )
        case .ocean:
            WidgetArtworkPalette(
                gradient: [Color(red: 0.18, green: 0.48, blue: 0.58), Color(red: 0.07, green: 0.23, blue: 0.34)],
                glow: Color(red: 0.55, green: 0.86, blue: 0.85),
                hill: Color(red: 0.04, green: 0.16, blue: 0.24)
            )
        }
    }
}

private struct WidgetArtworkPalette {
    let gradient: [Color]
    let glow: Color
    let hill: Color
}

private struct WidgetHillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.55))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.38),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.28),
            control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.76)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.18),
            control1: CGPoint(x: rect.width * 0.75, y: rect.height * 0.16),
            control2: CGPoint(x: rect.width * 0.86, y: rect.height * 0.43)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct WidgetBotanicalArtwork: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var stem = Path()
            stem.move(to: CGPoint(x: size.width * 0.48, y: size.height * 1.04))
            stem.addCurve(
                to: CGPoint(x: size.width * 0.62, y: size.height * 0.04),
                control1: CGPoint(x: size.width * 0.60, y: size.height * 0.68),
                control2: CGPoint(x: size.width * 0.53, y: size.height * 0.34)
            )
            context.stroke(stem, with: .color(color), lineWidth: 1.5)

            let leaves: [(Double, Double, Double)] = [
                (0.48, 0.20, -0.34), (0.67, 0.30, 0.34),
                (0.42, 0.43, -0.42), (0.68, 0.54, 0.38),
                (0.42, 0.66, -0.46), (0.64, 0.80, 0.42)
            ]
            let leafWidth = min(size.width * 0.26, 22)
            let leafHeight = min(size.height * 0.34, leafWidth * 2.2)

            for (x, y, rotation) in leaves {
                let centerX = size.width * x
                let centerY = size.height * y
                var leaf = Path()
                leaf.move(to: CGPoint(x: centerX, y: centerY + leafHeight / 2))
                leaf.addCurve(
                    to: CGPoint(x: centerX, y: centerY - leafHeight / 2),
                    control1: CGPoint(x: centerX - leafWidth * 0.72, y: centerY + leafHeight * 0.18),
                    control2: CGPoint(x: centerX - leafWidth * 0.58, y: centerY - leafHeight * 0.34)
                )
                leaf.addCurve(
                    to: CGPoint(x: centerX, y: centerY + leafHeight / 2),
                    control1: CGPoint(x: centerX + leafWidth * 0.58, y: centerY - leafHeight * 0.34),
                    control2: CGPoint(x: centerX + leafWidth * 0.72, y: centerY + leafHeight * 0.18)
                )
                leaf.closeSubpath()
                let transform = CGAffineTransform(translationX: size.width * x, y: size.height * y)
                    .rotated(by: rotation)
                    .translatedBy(x: -size.width * x, y: -size.height * y)
                leaf = leaf.applying(transform)
                context.fill(leaf, with: .color(color))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct ZenSoundsWidgets: Widget {
    let kind: String = "ZenSoundsDailyWord"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ZenSoundsWidgetConfigurationIntent.self,
            provider: DailyWordProvider()
        ) { entry in
            ZenSoundsWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Word of the Day")
        .description("Today's verse from Orante, with a quick way to read the full chapter.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "PSA", chapter: 23, verse: 1), text: "O SENHOR é meu pastor, nada me faltará.", bookName: "Salmos", backgroundTheme: .terracotta)
}

#Preview(as: .systemMedium) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "MAT", chapter: 6, verse: 26), text: "Olhai para as aves do céu, que não semeiam, nem ceifam, nem ajuntam em celeiros; e contudo vosso Pai celestial as alimenta.", bookName: "Mateus", backgroundTheme: .terracotta)
}

#Preview("Locked color", as: .systemMedium) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "PSA", chapter: 23, verse: 1), text: "O SENHOR é meu pastor, nada me faltará.", bookName: "Salmos", backgroundTheme: .terracotta, isLockedColor: true)
}

#Preview("Locked color small", as: .systemSmall) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "PSA", chapter: 23, verse: 1), text: "O SENHOR é meu pastor, nada me faltará.", bookName: "Salmos", backgroundTheme: .terracotta, isLockedColor: true)
}

#Preview(as: .accessoryRectangular) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "MAT", chapter: 28, verse: 20), text: "Ensinando-lhes a guardar todas as coisas que eu vos tenho mandado.", bookName: "Mateus", backgroundTheme: .terracotta)
}
#endif
