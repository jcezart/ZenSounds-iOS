import Foundation

/// Handles `zensounds://chapter/{book}/{chapter}/{verse}`, opened from the widget's tap target
/// (`widgetURL`) — routes straight to that chapter/verse in the Bible tab.
enum DeepLinkHandler {
    static func handle(_ url: URL) {
        guard let route = BibleDeepLink.parse(url) else { return }
        NavigationModel.shared.openBible(
            bookCode: route.book,
            chapter: route.chapter,
            focusVerse: route.verse
        )
    }
}

struct BibleDeepLink: Equatable {
    let book: String
    let chapter: Int
    let verse: Int

    var url: URL? {
        URL(string: "zensounds://chapter/\(book)/\(chapter)/\(verse)")
    }

    static func parse(_ url: URL) -> BibleDeepLink? {
        guard url.scheme == "zensounds", url.host == "chapter" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 3,
              let chapter = Int(components[1]), chapter > 0,
              let verse = Int(components[2]), verse > 0 else { return nil }
        return BibleDeepLink(book: components[0], chapter: chapter, verse: verse)
    }
}
