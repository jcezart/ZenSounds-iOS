import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case bible
    case rosary
    case sounds
    case favorites

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .bible: return "book.fill"
        case .rosary: return "circle.hexagongrid.fill"
        case .sounds: return "waveform"
        case .favorites: return "heart.fill"
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

enum SoundsRoute: Hashable {
    case mixEditor(existingMixId: String?)
}
