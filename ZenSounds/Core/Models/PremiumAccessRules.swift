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
    /// "Discover Orante+" in Settings: the offer itself, but it must still answer visibly without a paywall.
    case upgrade
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
        case .mixer, .savedMix, .customTimer, .guidedRosary, .upgrade:
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
        case .upgrade: "settings_upgrade"
        }
        return Self(name: name, parameters: parameters)
    }
}

/// Superwall's `restorePurchases()` shows its own alert (texts from `SuperwallOptions.paywalls.restoreFailed`,
/// localized by `SuperwallService`) whenever the restore fails or ends without an active entitlement. The app
/// only adds its own alert when the SDK stayed silent, so the user always sees exactly one.
enum RestoreAlertRules {
    enum AppMessage: Equatable {
        case restored
        case nothingFound
    }

    static func appMessage(restored: Bool, sdkHasActiveEntitlement: Bool, hasPlus: Bool) -> AppMessage? {
        guard restored && sdkHasActiveEntitlement else { return nil }
        return hasPlus ? .restored : .nothingFound
    }
}

#if DEBUG
/// Debug-only "Simular Orante+" switch. Compiled out of Release builds entirely.
enum DebugPlusOverride: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case subscriber
    case nonSubscriber

    static let storageKey = "orante.debug.plusOverride"

    var id: String { rawValue }

    func resolve(state: EntitlementState, hasPlus: Bool) -> (state: EntitlementState, hasPlus: Bool) {
        switch self {
        case .automatic: (state, hasPlus)
        case .subscriber: (.active, true)
        case .nonSubscriber: (.inactive, false)
        }
    }
}
#endif

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

/// What happened on the Superwall side by the time it hands control back to the app.
struct PaywallOutcome: Equatable, Sendable {
    /// A paywall was actually shown to the user (so the app must not show its own notice).
    var paywallPresented: Bool
    /// The paywall closed with a purchase or restore; the entitlement may still be propagating.
    var purchasedOrRestored: Bool

    /// No paywall: placement not found, no matching audience, holdout, error or no network.
    static let notPresented = PaywallOutcome(paywallPresented: false, purchasedOrRestored: false)
}

@MainActor
final class PremiumGate {
    /// Registers the placement and calls `onOutcome` whenever Superwall would release the feature
    /// (or fails to present). The gate — not Superwall — decides whether the feature actually runs.
    typealias Registrar = (_ placement: PremiumPlacement, _ onOutcome: @escaping (PaywallOutcome) -> Void) -> Void

    private let entitlements: any EntitlementProviding
    private let registrar: Registrar
    private let waitForEntitlement: () async -> Void
    private let onLocked: (PremiumFeature) -> Void

    /// - Parameters:
    ///   - waitForEntitlement: awaited after a purchase/restore when `hasPlus` hasn't flipped yet.
    ///   - onLocked: shows the "Orante+ feature" notice when no paywall was presented and access is denied.
    init(
        entitlements: any EntitlementProviding,
        registrar: @escaping Registrar,
        waitForEntitlement: @escaping () async -> Void = {},
        onLocked: @escaping (PremiumFeature) -> Void = { _ in }
    ) {
        self.entitlements = entitlements
        self.registrar = registrar
        self.waitForEntitlement = waitForEntitlement
        self.onLocked = onLocked
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

        registrar(.request(for: feature, parameters: parameters)) { [weak self] outcome in
            guard let self else { return }
            if outcome.purchasedOrRestored && !self.entitlements.hasPlus {
                Task { @MainActor in
                    await self.resolve(feature, outcome: outcome, perform: perform)
                }
            } else {
                self.finish(feature, outcome: outcome, perform: perform)
            }
        }
    }

    /// Waits for a just-purchased entitlement to propagate, then re-checks access.
    func resolve(_ feature: PremiumFeature, outcome: PaywallOutcome, perform: () -> Void) async {
        if outcome.purchasedOrRestored && !entitlements.hasPlus {
            await waitForEntitlement()
        }
        finish(feature, outcome: outcome, perform: perform)
    }

    /// Superwall releases the feature even when no campaign matched, so access is re-checked here.
    private func finish(_ feature: PremiumFeature, outcome: PaywallOutcome, perform: () -> Void) {
        if entitlements.hasPlus {
            perform()
        } else if !outcome.paywallPresented {
            onLocked(feature)
        }
    }

    func shouldShowBadge(for feature: PremiumFeature) -> Bool {
        entitlements.entitlementState == .inactive
            && PremiumAccessRules.requiresPlus(for: feature)
            && !entitlements.hasPlus
    }
}
