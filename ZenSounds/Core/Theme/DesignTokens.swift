import SwiftUI

// MARK: - Design tokens
//
// The single source for Orante's visual language: colors (light + dark), typography, spacing and
// corner radii. Views read colors from `@Environment(\.essencePalette)` and use the `.essence*` /
// `.scripture*` fonts below — no loose hex values or font sizes in feature code.

// MARK: Colors

/// Warm palette in two variants. Light matches the paywall (`#F5F1EB` / `#FFFDF9` / `#A3533C` /
/// `#656747` / `#292622`); dark follows the redesign mockups (warm near-black, peach accent).
struct EssencePalette: Equatable {
    let background: Color
    let surface: Color
    /// Raised surface on top of `surface` (selected verse block, list rows on cards, mini-player).
    let surfaceElevated: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let onAccent: Color
    /// Word of the Day card background (terracotta).
    let verseBackground: Color
    let onVerse: Color
    /// Subtle fill for chips, placeholders and selected states.
    let lilac: Color
    let outline: Color
    let track: Color
    let foliage: Color
}

extension EssencePalette {
    static let light = EssencePalette(
        background: Color(hex: 0xF5F1EB),
        surface: Color(hex: 0xFFFDF9),
        surfaceElevated: Color(hex: 0xF1E9E1),
        text: Color(hex: 0x292622),
        secondaryText: Color(hex: 0x6E6864),
        accent: Color(hex: 0xA3533C),
        onAccent: .white,
        verseBackground: Color(hex: 0x98503B),
        onVerse: Color(hex: 0xFFFAF3),
        lilac: Color(hex: 0xEDE4DA),
        outline: Color(hex: 0xE5DDD5),
        track: Color(hex: 0xDDD2C8),
        foliage: Color(hex: 0x656747)
    )

    static let dark = EssencePalette(
        background: Color(hex: 0x1B1816),
        surface: Color(hex: 0x262120),
        surfaceElevated: Color(hex: 0x332C29),
        text: Color(hex: 0xF5EFE7),
        secondaryText: Color(hex: 0xBDB2AA),
        accent: Color(hex: 0xE9AC8F),
        onAccent: Color(hex: 0x2C1B15),
        verseBackground: Color(hex: 0x7A4433),
        onVerse: Color(hex: 0xFFF6EB),
        lilac: Color(hex: 0x3A312D),
        outline: Color(hex: 0x3E3532),
        track: Color(hex: 0x4D423D),
        foliage: Color(hex: 0xB8BA92)
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct EssencePaletteKey: EnvironmentKey {
    static let defaultValue = EssencePalette.light
}

extension EnvironmentValues {
    var essencePalette: EssencePalette {
        get { self[EssencePaletteKey.self] }
        set { self[EssencePaletteKey.self] = newValue }
    }
}

// MARK: Typography

/// Plus Jakarta Sans is still bundled (and registered in Info.plist) so it can be restored quickly,
/// but the interface now uses SF Pro through system text styles.
enum EssenceFont {
    static let regular = "PlusJakartaSans-Regular"
    static let medium = "PlusJakartaSans-Medium"
    static let semibold = "PlusJakartaSans-SemiBold"
    static let bold = "PlusJakartaSans-Bold"
}

/// Interface styles (SF Pro). Built on text styles, so every one scales with Dynamic Type.
extension Font {
    static let essenceDisplaySmall = Font.system(.largeTitle, weight: .bold)
    static let essenceHeadlineMedium = Font.system(.title, weight: .bold)
    static let essenceTitleLarge = Font.system(.title2, weight: .bold)
    static let essenceTitleMedium = Font.system(.headline)
    static let essenceBodyLarge = Font.system(.body)
    static let essenceBodyMedium = Font.system(.callout)
    static let essenceBodySmall = Font.system(.footnote)
    static let essenceLabelLarge = Font.system(.subheadline, weight: .semibold)
    static let essenceLabelMedium = Font.system(.caption, weight: .medium)

    /// Serif (New York) for scripture, prayers and chapter titles.
    static let scriptureTitle = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let scriptureHeadline = Font.system(.title2, design: .serif)
    static let scriptureBody = Font.system(.title3, design: .serif)
    static let scriptureCaption = Font.system(.callout, design: .serif).italic()
}

// MARK: Spacing & radii

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Horizontal margin of every screen.
    static let screen: CGFloat = 20
}

enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
}
