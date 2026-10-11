import SwiftUI

/// Plus Jakarta Sans, bundled from the Android app (`res/font/essence_jakarta_*.ttf`).
/// Each weight is registered as its own PostScript name via `UIAppFonts` in Info.plist
/// (the original TTFs all shared the same internal "Regular" PostScript name — a latent
/// bug invisible on Android, which loads fonts by file path, but fatal on iOS, which
/// resolves fonts by name. Fixed by rewriting each file's name table during migration.)
enum EssenceFont {
    static let regular = "PlusJakartaSans-Regular"
    static let medium = "PlusJakartaSans-Medium"
    static let semibold = "PlusJakartaSans-SemiBold"
    static let bold = "PlusJakartaSans-Bold"
}

/// Mirrors the Android `EssenceTypography` scale (`ui/theme/Theme.kt`). Every style uses
/// `Font.custom(_:size:relativeTo:)` so text scales with Dynamic Type.
extension Font {
    static let essenceDisplaySmall = Font.custom(EssenceFont.bold, size: 36, relativeTo: .largeTitle)
    static let essenceHeadlineMedium = Font.custom(EssenceFont.semibold, size: 26, relativeTo: .title)
    static let essenceTitleLarge = Font.custom(EssenceFont.bold, size: 22, relativeTo: .title2)
    static let essenceTitleMedium = Font.custom(EssenceFont.semibold, size: 16, relativeTo: .headline)
    static let essenceBodyLarge = Font.custom(EssenceFont.regular, size: 18, relativeTo: .body)
    static let essenceBodyMedium = Font.custom(EssenceFont.regular, size: 14, relativeTo: .callout)
    static let essenceBodySmall = Font.custom(EssenceFont.regular, size: 12, relativeTo: .footnote)
    static let essenceLabelLarge = Font.custom(EssenceFont.semibold, size: 14, relativeTo: .subheadline)
    static let essenceLabelMedium = Font.custom(EssenceFont.medium, size: 12, relativeTo: .caption)
}
