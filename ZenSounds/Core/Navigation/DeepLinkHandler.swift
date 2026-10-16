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

/// `zensounds://plus` — opened by the widget when it shows a paid color the user can't use yet;
/// the app answers by registering the `widget_theme` placement.
enum PlusDeepLink {
    static let url = URL(string: "zensounds://plus")!

    static func matches(_ url: URL) -> Bool {
        url.scheme == "zensounds" && url.host == "plus"
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
              BibleCatalog.shared.book(code: components[0]) != nil,
              let chapter = Int(components[1]), chapter > 0,
              let verse = Int(components[2]), verse > 0 else { return nil }
        return BibleDeepLink(book: components[0], chapter: chapter, verse: verse)
    }
}
