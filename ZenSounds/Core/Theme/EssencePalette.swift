import SwiftUI

/// Exact light/dark palette ported from the Android app's `ui/theme/Theme.kt`
/// (`EssenceLight` / `EssenceDark`). Hex values captured from the source project.
struct EssencePalette: Equatable {
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let onAccent: Color
    let verseBackground: Color
    let onVerse: Color
    let lilac: Color
    let outline: Color
    let track: Color
    let foliage: Color
}

extension EssencePalette {
    static let light = EssencePalette(
        background: Color(hex: 0xF5F1EB),
        surface: Color(hex: 0xFFFDF9),
        text: Color(hex: 0x292622),
        secondaryText: Color(hex: 0x6E6864),
        accent: Color(hex: 0xA3533C),
        onAccent: .white,
        verseBackground: Color(hex: 0x98503B),
        onVerse: Color(hex: 0xFFFAF3),
        lilac: Color(hex: 0xE5DEEB),
        outline: Color(hex: 0xE5DDD5),
        track: Color(hex: 0xDED6E0),
        foliage: Color(hex: 0x656747)
    )

    static let dark = EssencePalette(
        background: Color(hex: 0x181719),
        surface: Color(hex: 0x242226),
        text: Color(hex: 0xF5EFE7),
        secondaryText: Color(hex: 0xBAB1AC),
        accent: Color(hex: 0xE3AA8E),
        onAccent: Color(hex: 0x2C1B15),
        verseBackground: Color(hex: 0x754231),
        onVerse: Color(hex: 0xFFF6EB),
        lilac: Color(hex: 0x39323F),
        outline: Color(hex: 0x3B3539),
        track: Color(hex: 0x49404B),
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
