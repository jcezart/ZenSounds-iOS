import Foundation

enum EntitlementState: Equatable, Sendable {
    case unknown
    case inactive
    case active
}

@MainActor
protocol EntitlementProviding: AnyObject {
    var hasPlus: Bool { get }
    var entitlementState: EntitlementState { get }
}

enum PremiumFeature: Equatable, Sendable {
    case sound(id: String)
    case soundscape(id: String)
    case mixer
    case savedMix
    case customTimer
    case verseNarration(isDailyWord: Bool)
    case guidedRosary
    case widgetTheme(id: String)
}

enum PremiumAccessRules {
    private static let freeSoundIDs: Set<String> = ["Rain", "Forest", "Stream"]
    private static let freeSoundscapeIDs: Set<String> = ["good-shepherd"]
    static let widgetThemeIDs = ["terracotta", "forest", "midnight", "plum", "ocean"]
    static let freeTimerPresets = [5, 15, 30, 60]

    static func isFreeSound(_ id: String) -> Bool {
        freeSoundIDs.contains(id)
    }

    static func isFreeSoundscape(_ id: String) -> Bool {
        freeSoundscapeIDs.contains(id)
    }

    static func isFreeTimerPreset(_ minutes: Int) -> Bool {
        freeTimerPresets.contains(minutes)
    }

    static func resolvedWidgetThemeID(_ selectedID: String, hasPlus: Bool) -> String {
        hasPlus ? selectedID : "terracotta"
    }

    static func requiresPlus(for feature: PremiumFeature) -> Bool {
        switch feature {
        case .sound(let id):
            !isFreeSound(id)
        case .soundscape(let id):
            !isFreeSoundscape(id)
        case .verseNarration(let isDailyWord):
            !isDailyWord
        case .widgetTheme(let id):
            id != "terracotta"
        case .mixer, .savedMix, .customTimer, .guidedRosary:
            true
        }
    }
}

enum AudioPremiumSafety {
    enum StartDecision: Equatable {
        case startRequestedSound
        case keepCurrentPlayback
    }

    static func canStartSound(id: String, hasPlus: Bool) -> Bool {
        hasPlus || PremiumAccessRules.isFreeSound(id)
    }

    static func canStartMix(id: String, hasPlus: Bool) -> Bool {
        if let soundscape = BiblicalSoundscapeCatalog.soundscape(forMixID: id) {
            return hasPlus || PremiumAccessRules.isFreeSoundscape(soundscape.id)
        }
        return hasPlus
    }

    static func decisionForSoundStart(id: String, hasPlus: Bool) -> StartDecision {
        canStartSound(id: id, hasPlus: hasPlus) ? .startRequestedSound : .keepCurrentPlayback
    }

    static func playbackAfterEntitlementChange(currentSoundID: String?) -> String? {
        currentSoundID
    }
}

struct PremiumPlacement: Equatable, Sendable {
    let name: String
    let parameters: [String: String]

    static func request(for feature: PremiumFeature, parameters: [String: String] = [:]) -> Self {
        let name = switch feature {
        case .sound: "premium_sound"
        case .soundscape: "premium_soundscape"
        case .mixer, .savedMix: "create_mix"
        case .verseNarration: "bible_narration"
        case .guidedRosary: "guided_rosary"
        case .customTimer: "custom_timer"
        case .widgetTheme: "widget_theme"
        }
        return Self(name: name, parameters: parameters)
    }
}

struct EntitlementAccessSnapshot: Equatable, Sendable {
    let state: EntitlementState
    let hasPlus: Bool
    let cachedPlus: Bool
}

enum EntitlementCacheRules {
    static func resolve(
        status: EntitlementState,
        plusIsActive: Bool = false,
        cachedPlus: Bool
    ) -> EntitlementAccessSnapshot {
        switch status {
        case .unknown:
            EntitlementAccessSnapshot(state: .unknown, hasPlus: cachedPlus, cachedPlus: cachedPlus)
        case .inactive:
            EntitlementAccessSnapshot(state: .inactive, hasPlus: false, cachedPlus: false)
        case .active:
            EntitlementAccessSnapshot(state: .active, hasPlus: plusIsActive, cachedPlus: plusIsActive)
        }
    }
}

@MainActor
final class PremiumGate {
    typealias Registrar = (_ placement: PremiumPlacement, _ feature: @escaping () -> Void) -> Void

    private let entitlements: any EntitlementProviding
    private let registrar: Registrar

    init(entitlements: any EntitlementProviding, registrar: @escaping Registrar) {
        self.entitlements = entitlements
        self.registrar = registrar
    }

    func gate(
        _ feature: PremiumFeature,
        parameters: [String: String] = [:],
        perform: @escaping () -> Void
    ) {
        guard PremiumAccessRules.requiresPlus(for: feature), !entitlements.hasPlus else {
            perform()
            return
        }

        registrar(.request(for: feature, parameters: parameters), perform)
    }

    func shouldShowBadge(for feature: PremiumFeature) -> Bool {
        entitlements.entitlementState == .inactive
            && PremiumAccessRules.requiresPlus(for: feature)
            && !entitlements.hasPlus
    }
}
