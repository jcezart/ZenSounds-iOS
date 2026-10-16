import Foundation

/// The four tabs of the redesign. Sounds and Favorites are no longer tabs: the sound library lives in
/// Search → Explore → Sounds (and the "Ambient sound" sheet), and Favorites inside Search.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case bible
    case rosary
    case search

    var id: String { rawValue }

    /// Outline variants; the tab bar fills the selected one automatically.
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .bible: return "book"
        case .rosary: return "circle.hexagongrid"
        case .search: return "magnifyingglass"
        }
    }
}

/// Opaque navigation destinations pushed within the Bible tab's own stack (and reused from
/// Home's "Explore <Book>" card). `focusVerse` lets a deep link (widget tap) land on a
/// specific verse within the chapter.
enum BibleRoute: Hashable {
    case chapters(bookCode: String)
    case verses(bookCode: String, chapter: Int, focusVerse: Int?)
}

/// Sound screens, pushable from any tab (Home "My mix", Search → Explore → Sounds, the ambient sheet).
enum SoundsRoute: Hashable {
    /// Full library: soundscapes, saved mixes, every sound, create mix.
    case library
    case mixEditor(existingMixId: String?)
}

/// Screens reachable from the Search tab.
enum SearchRoute: Hashable {
    case favorites
    /// Rosary prayers with their full text (Search → Explore → Prayers).
    case prayers
    case prayer(id: String)
}
