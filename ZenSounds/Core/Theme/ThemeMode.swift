import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "zensounds.theme_mode"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = ThemeMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .system
        }
    }

    func palette(for systemColorScheme: ColorScheme) -> EssencePalette {
        switch mode {
        case .system: return systemColorScheme == .dark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Non-nil forces SwiftUI's `preferredColorScheme`; nil lets the system decide.
    var colorSchemeOverride: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
