import SwiftUI

/// Root theming wrapper, equivalent to the Android `ZenSoundsTheme` composable: resolves the
/// active palette from `ThemeManager.mode` + the real system color scheme, injects it into the
/// environment, tints controls with the accent color, and forces light/dark when the user has
/// overridden the system default.
struct ZenSoundsTheme<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        let palette = themeManager.palette(for: systemColorScheme)
        content()
            .environment(\.essencePalette, palette)
            .tint(palette.accent)
            .preferredColorScheme(themeManager.colorSchemeOverride)
    }
}
