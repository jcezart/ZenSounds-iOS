import Foundation

/// Handles `zensounds://chapter/{book}/{chapter}/{verse}`, opened from the widget's tap target
/// (`widgetURL`) — routes straight to that chapter/verse in the Bible tab.
enum DeepLinkHandler {
    static func handle(_ url: URL) {
        guard url.scheme == "zensounds", url.host == "chapter" else { return }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 3,
              let chapter = Int(components[1]),
              let verse = Int(components[2]) else { return }
        NavigationModel.shared.openBible(bookCode: components[0], chapter: chapter, focusVerse: verse)
    }
}
