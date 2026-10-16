import Foundation

// MARK: - Recents

/// Something the person opened recently, shown in Search → Recent. Persisted in `zensounds.recents.v1`.
enum RecentItem: Codable, Hashable {
    case chapter(bookCode: String, chapter: Int)
    case book(bookCode: String)
    case mysteries(RosaryMysterySetID)
}

enum RecentsRules {
    static let maxStored = 10
    static let maxDisplayed = 5

    /// Moves `item` to the top (repeats go up instead of duplicating) and keeps at most `maxStored`.
    static func adding(_ item: RecentItem, to items: [RecentItem]) -> [RecentItem] {
        Array(([item] + items.filter { $0 != item }).prefix(maxStored))
    }
}

// MARK: - Text folding

nonisolated enum SearchText {
    /// Lowercased, accent-insensitive, trimmed, single-spaced ("  São  JOÃO " → "sao joao").
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Folded with punctuation as spaces, for text matching ("Salve-Rainha" matches "salve rainha").
    static func words(_ text: String) -> String {
        String(fold(text).map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Folded without spaces, so "1 sm", "1sm" and "1 Samuel" compare on the same key.
    static func compact(_ text: String) -> String {
        fold(text).replacingOccurrences(of: " ", with: "")
    }
}

// MARK: - Books

/// Common abbreviations per Bible language. Only the active language's table is used, because the
/// same letters mean different books across languages ("jo" = João in pt, "jn" = John in en).
enum BookAbbreviations {
    static let pt: [String: [String]] = [
        "GEN": ["gn", "gen"], "EXO": ["ex", "exo", "exod"], "LEV": ["lv", "lev"], "NUM": ["nm", "num"],
        "DEU": ["dt", "deut"], "JOS": ["js", "jos"], "JDG": ["jz", "juiz"], "RUT": ["rt"],
        "1SA": ["1sm", "1sam"], "2SA": ["2sm", "2sam"], "1KI": ["1rs"], "2KI": ["2rs"],
        "1CH": ["1cr", "1cro"], "2CH": ["2cr", "2cro"], "EZR": ["ed", "esd"], "NEH": ["ne", "nee"],
        "EST": ["et", "est"], "JOB": ["jb"], "PSA": ["sl", "sal", "salmo"], "PRO": ["pv", "pr", "prov"],
        "ECC": ["ec", "ecl"], "SNG": ["ct", "cant", "cantico", "canticos"], "ISA": ["is", "isa"],
        "JER": ["jr", "jer"], "LAM": ["lm", "lam"], "EZK": ["ez", "eze"], "DAN": ["dn", "dan"],
        "HOS": ["os"], "JOL": ["jl"], "AMO": ["am"], "OBA": ["ob", "abd"], "JON": ["jn"],
        "MIC": ["mq"], "NAM": ["na"], "HAB": ["hc", "hab"], "ZEP": ["sf"], "HAG": ["ag"],
        "ZEC": ["zc", "zac"], "MAL": ["ml", "mal"], "MAT": ["mt"], "MRK": ["mc"], "LUK": ["lc"],
        "JHN": ["jo"], "ACT": ["at"], "ROM": ["rm", "rom"], "1CO": ["1co", "1cor"], "2CO": ["2co", "2cor"],
        "GAL": ["gl", "gal"], "EPH": ["ef"], "PHP": ["fp", "fl", "fil"], "COL": ["cl", "col"],
        "1TH": ["1ts"], "2TH": ["2ts"], "1TI": ["1tm"], "2TI": ["2tm"], "TIT": ["tt"], "PHM": ["fm", "flm"],
        "HEB": ["hb", "heb"], "JAS": ["tg"], "1PE": ["1pe", "1pd"], "2PE": ["2pe", "2pd"],
        "1JN": ["1jo"], "2JN": ["2jo"], "3JN": ["3jo"], "JUD": ["jd"], "REV": ["ap", "apoc"]
    ]

    static let en: [String: [String]] = [
        "GEN": ["gn", "ge", "gen"], "EXO": ["ex", "exo", "exod"], "LEV": ["lv", "lev"], "NUM": ["nm", "nu", "num"],
        "DEU": ["dt", "deut"], "JOS": ["jos", "josh"], "JDG": ["jdg", "judg"], "RUT": ["ru", "rth"],
        "1SA": ["1sa", "1sam", "1sm"], "2SA": ["2sa", "2sam", "2sm"], "1KI": ["1ki", "1kgs"], "2KI": ["2ki", "2kgs"],
        "1CH": ["1ch", "1chr"], "2CH": ["2ch", "2chr"], "EZR": ["ezr"], "NEH": ["ne", "neh"],
        "EST": ["est", "esth"], "JOB": ["jb"], "PSA": ["ps", "psa", "pss", "psalm"], "PRO": ["pr", "prv", "prov"],
        "ECC": ["ec", "ecc", "eccl"], "SNG": ["sos", "song", "ss"], "ISA": ["is", "isa"],
        "JER": ["jer", "jr"], "LAM": ["la", "lam"], "EZK": ["eze", "ezek", "ezk"], "DAN": ["da", "dn", "dan"],
        "HOS": ["ho", "hos"], "JOL": ["jl"], "AMO": ["am"], "OBA": ["ob", "obad"], "JON": ["jon", "jnh"],
        "MIC": ["mic", "mi"], "NAM": ["na", "nah"], "HAB": ["hab", "hb"], "ZEP": ["zep", "zeph"], "HAG": ["hag", "hg"],
        "ZEC": ["zec", "zech"], "MAL": ["mal", "ml"], "MAT": ["mt", "matt"], "MRK": ["mk", "mrk"], "LUK": ["lk", "luk"],
        "JHN": ["jn", "jhn"], "ACT": ["ac", "act"], "ROM": ["ro", "rm", "rom"], "1CO": ["1co", "1cor"], "2CO": ["2co", "2cor"],
        "GAL": ["ga", "gal"], "EPH": ["eph"], "PHP": ["php", "phil"], "COL": ["col"],
        "1TH": ["1th", "1thess"], "2TH": ["2th", "2thess"], "1TI": ["1ti", "1tim"], "2TI": ["2ti", "2tim"],
        "TIT": ["tit"], "PHM": ["phm", "phlm"], "HEB": ["heb"], "JAS": ["jas", "jm"], "1PE": ["1pe", "1pet"],
        "2PE": ["2pe", "2pet"], "1JN": ["1jn", "1jo"], "2JN": ["2jn", "2jo"], "3JN": ["3jn", "3jo"], "JUD": ["jud", "jude"],
        "REV": ["re", "rev", "rv"]
    ]

    static func table(for language: BibleLanguage) -> [String: [String]] {
        language == .pt ? pt : en
    }
}

enum BookMatcher {
    /// Books matching `query`, best first: exact abbreviation, exact name, name prefix, abbreviation
    /// prefix, then name containing the query. Names match in both languages; abbreviations only in
    /// the active one.
    static func matches(_ query: String, in books: [BibleBook], language: BibleLanguage) -> [BibleBook] {
        scoredMatches(query, in: books, language: language).map(\.book)
    }

    /// Lower score = better match.
    static func scoredMatches(_ query: String, in books: [BibleBook], language: BibleLanguage) -> [(book: BibleBook, score: Int)] {
        let key = SearchText.compact(query)
        guard !key.isEmpty else { return [] }
        let abbreviations = BookAbbreviations.table(for: language)

        let scored: [(book: BibleBook, score: Int)] = books.compactMap { book in
            let names = [book.namePt, book.nameEn].map(SearchText.compact)
            let abbrevs = abbreviations[book.code] ?? []
            let score: Int
            if abbrevs.contains(key) {
                score = 0
            } else if names.contains(key) {
                score = 1
            } else if names.contains(where: { $0.hasPrefix(key) }) {
                score = 2
            } else if abbrevs.contains(where: { $0.hasPrefix(key) }) {
                score = 3
            } else if key.count >= 3, names.contains(where: { $0.contains(key) }) {
                score = 4
            } else {
                return nil
            }
            return (book, score)
        }
        return scored
            .sorted { $0.score != $1.score ? $0.score < $1.score : $0.book.order < $1.book.order }
    }
}

// MARK: - References

/// A parsed "book chapter[:verse]" query, e.g. "jo 3:16", "Salmo 23", "gn 1".
struct PassageReference: Hashable {
    let bookCode: String
    let chapter: Int
    let verse: Int?
}

enum ReferenceParser {
    /// Book text (must contain a letter), chapter and optional verse separated by ":", "." or ",".
    private static let pattern = /^(.*?\p{L}.*?)\s*(\d{1,3})(?:\s*[:.,]\s*(\d{1,3}))?$/

    static func parse(_ query: String, books: [BibleBook], language: BibleLanguage, limit: Int = 3) -> [PassageReference] {
        let folded = SearchText.fold(query)
        guard let match = folded.wholeMatch(of: pattern),
              let chapter = Int(match.2), chapter > 0 else { return [] }
        let verse = match.3.flatMap { Int($0) }
        if let verse, verse <= 0 { return [] }

        // Only the best tier: "jo 3:16" is João 3:16, not also Jó, Joel or Josué.
        let candidates = BookMatcher.scoredMatches(String(match.1), in: books, language: language)
            .filter { chapter <= $0.book.chapters }
        guard let best = candidates.first?.score else { return [] }
        return candidates
            .filter { $0.score == best }
            .map(\.book)
            .prefix(limit)
            .map { PassageReference(bookCode: $0.code, chapter: chapter, verse: verse) }
    }
}

// MARK: - Rosary content

enum RosarySearch {
    struct PrayerHit: Hashable {
        let id: String
        let kind: RosaryPrayerKind
    }

    struct MysteryHit: Hashable {
        let set: RosaryMysterySetID
        /// nil when the set name itself matched.
        let mysteryID: String?
    }

    static func prayers(_ query: String, in prayers: [RosaryPrayer], language: BibleLanguage) -> [PrayerHit] {
        let key = SearchText.words(query)
        guard key.count >= 2 else { return [] }
        return prayers.compactMap { prayer in
            guard let kind = RosaryPrayerKind(rawValue: prayer.id) else { return nil }
            let names = [BibleLanguage.pt, .en].map { SearchText.words(RosaryLabels.prayerName(kind, language: $0)) }
            let text = SearchText.words(language == .pt ? prayer.pt : prayer.en)
            guard names.contains(where: { $0.contains(key) }) || (key.count >= 3 && text.contains(key)) else { return nil }
            return PrayerHit(id: prayer.id, kind: kind)
        }
    }

    static func mysteries(_ query: String, in sets: [RosaryMysterySet]) -> [MysteryHit] {
        let key = SearchText.words(query)
        guard key.count >= 3 else { return [] }
        var hits: [MysteryHit] = []
        for set in sets {
            if [set.name.pt, set.name.en].map(SearchText.words).contains(where: { $0.contains(key) }) {
                hits.append(MysteryHit(set: set.id, mysteryID: nil))
            }
            for mystery in set.mysteries where [mystery.name.pt, mystery.name.en].map(SearchText.words).contains(where: { $0.contains(key) }) {
                hits.append(MysteryHit(set: set.id, mysteryID: mystery.id))
            }
        }
        return hits
    }
}

// MARK: - Verse text

/// Rules for the full-text verse search (async, debounced, limited).
nonisolated enum VerseSearchRules {
    static let minimumQueryLength = 3
    static let resultLimit = 50
    static let debounce: Duration = .milliseconds(300)
}
