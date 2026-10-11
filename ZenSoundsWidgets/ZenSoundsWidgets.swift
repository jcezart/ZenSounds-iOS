import WidgetKit
import SwiftUI
import AppIntents

struct DailyWordEntry: TimelineEntry {
    let date: Date
    let reading: WidgetReadingRef
    let text: String
    let bookName: String

    var deepLinkURL: URL? {
        URL(string: "zensounds://chapter/\(reading.book)/\(reading.chapter)/\(reading.verse)")
    }
}

struct DailyWordProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyWordEntry {
        DailyWordEntry(
            date: Date(),
            reading: WidgetReadingRef(book: "PSA", chapter: 23, verse: 1),
            text: "O SENHOR é meu pastor, nada me faltará.",
            bookName: "Salmos"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyWordEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyWordEntry>) -> Void) {
        let entry = currentEntry()
        // The word only changes at local midnight; ask the system to check back then. WidgetKit
        // treats this as a best-effort budget request, not a guaranteed exact-time refresh.
        let nextMidnight = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> DailyWordEntry {
        let source = WidgetDataSource.shared
        let store = WidgetDailyWordStore()
        let ref = store.reference(for: Date(), readings: source.readings)
        let language = WidgetLanguage.systemDefault
        let reading = source.readings.first { $0.book == ref.book && $0.chapter == ref.chapter && $0.verse == ref.verse }
        let text = reading.map { source.text(for: $0, language: language) } ?? ""
        let bookName = source.book(code: ref.book).map { language == .pt ? $0.name_pt : $0.name_en } ?? ref.book
        return DailyWordEntry(date: Date(), reading: ref, text: text, bookName: bookName)
    }
}

struct ZenSoundsWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DailyWordEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallDailyWordView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        default:
            MediumDailyWordView(entry: entry)
        }
    }
}

/// Home screen color (matches `EssencePalette.light.verseBackground`) — widgets render in their
/// own process without access to the app's environment-based theme, so the daily-word card
/// color is reproduced directly here.
private let verseBackground = Color(red: 0x98 / 255.0, green: 0x50 / 255.0, blue: 0x3B / 255.0)

private extension View {
    func zenWidgetBackground() -> some View {
        containerBackground(for: .widget) { verseBackground }
    }
}

struct SmallDailyWordView: View {
    let entry: DailyWordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORD OF THE DAY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(entry.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .zenWidgetBackground()
        .widgetURL(entry.deepLinkURL)
    }
}

struct MediumDailyWordView: View {
    let entry: DailyWordEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WORD OF THE DAY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Button(intent: ShuffleDailyWordIntent()) {
                    Image(systemName: "shuffle")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show another verse")
            }
            Text(entry.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(family == .systemLarge ? 10 : 5)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 2)
            Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .zenWidgetBackground()
        .widgetURL(entry.deepLinkURL)
    }
}

struct LockScreenRectangularView: View {
    let entry: DailyWordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.text).font(.caption2).lineLimit(3)
            Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)").font(.caption2).bold()
        }
        .widgetURL(entry.deepLinkURL)
    }
}

struct LockScreenInlineView: View {
    let entry: DailyWordEntry

    var body: some View {
        Text("\(entry.bookName) \(entry.reading.chapter):\(entry.reading.verse)")
            .widgetURL(entry.deepLinkURL)
    }
}

struct LockScreenCircularView: View {
    let entry: DailyWordEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "book.fill")
                Text("\(entry.reading.chapter)")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .widgetURL(entry.deepLinkURL)
    }
}

struct ZenSoundsWidgets: Widget {
    let kind: String = "ZenSoundsDailyWord"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyWordProvider()) { entry in
            ZenSoundsWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Word of the Day")
        .description("Today's verse from ZenSounds, with a quick way to read the full chapter.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "PSA", chapter: 23, verse: 1), text: "O SENHOR é meu pastor, nada me faltará.", bookName: "Salmos")
}

#Preview(as: .systemMedium) {
    ZenSoundsWidgets()
} timeline: {
    DailyWordEntry(date: .now, reading: WidgetReadingRef(book: "MAT", chapter: 6, verse: 26), text: "Olhai para as aves do céu, que não semeiam, nem ceifam, nem ajuntam em celeiros; e contudo vosso Pai celestial as alimenta.", bookName: "Mateus")
}
