import Foundation
import Combine
import SuperwallKit
import WidgetKit

@MainActor
final class SuperwallService: ObservableObject, SuperwallDelegate, EntitlementProviding {
    enum Placement {
        static let premiumSound = "premium_sound"
        static let premiumSoundscape = "premium_soundscape"
        static let createMix = "create_mix"
        static let bibleNarration = "bible_narration"
        static let guidedRosary = "guided_rosary"
        static let customTimer = "custom_timer"
        static let widgetTheme = "widget_theme"
        static let onboardingEnd = "onboarding_end"
        static let settingsUpgrade = "settings_upgrade"
    }

    static let shared = SuperwallService()

    @Published private(set) var entitlementState: EntitlementState = .unknown
    @Published private(set) var hasPlus: Bool

    var isSubscribed: Bool { hasPlus }
    var shouldShowPremiumBadges: Bool { entitlementState == .inactive && !hasPlus }

    private static let apiKey = "pk_Fiv1oYMGZPUzCmnAUxtZc"
    private static let plusEntitlementID = "plus"
    private static let cachedPlusKey = "orante.plus.lastConfirmedActive"
    static let appGroupID = "group.com.juliocezar.zensounds"
    static let widgetPlusKey = "plus_active"
    private var isConfigured = false

    lazy var premiumGate = PremiumGate(entitlements: self) { placement, feature in
        Superwall.shared.register(
            placement: placement.name,
            params: placement.parameters,
            feature: feature
        )
    }

    private init() {
        hasPlus = UserDefaults.standard.bool(forKey: Self.cachedPlusKey)
    }

    func configure(language: AppLanguage) {
        guard !isConfigured else {
            updateUserProperties(language: language)
            return
        }

        isConfigured = true
        let superwall = Superwall.configure(apiKey: Self.apiKey)
        superwall.delegate = self
        apply(superwall.subscriptionStatus)
        updateUserProperties(language: language)
    }

    func identify(userID: UUID, properties: [String: Any?] = [:]) {
        Superwall.shared.identify(userId: userID.uuidString)
        if !properties.isEmpty {
            Superwall.shared.setUserAttributes(properties)
        }
    }

    func resetUser() {
        Superwall.shared.reset()
        apply(Superwall.shared.subscriptionStatus)
    }

    func register(
        placement: String,
        parameters: [String: Any]? = nil,
        feature: @escaping () -> Void
    ) {
        Superwall.shared.register(
            placement: placement,
            params: parameters,
            feature: feature
        )
    }

    func gate(
        _ feature: PremiumFeature,
        parameters: [String: String] = [:],
        perform: @escaping () -> Void
    ) {
        premiumGate.gate(feature, parameters: parameters, perform: perform)
    }

    func registerNonGated(placement: String, parameters: [String: String] = [:]) {
        Superwall.shared.register(placement: placement, params: parameters) {}
    }

    enum RestoreOutcome {
        case restored
        case nothingFound
        case failed
    }

    func restorePurchases() async -> RestoreOutcome {
        switch await Superwall.shared.restorePurchases() {
        case .restored:
            apply(Superwall.shared.subscriptionStatus)
            return hasPlus ? .restored : .nothingFound
        case .failed:
            return .failed
        }
    }

    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        Superwall.handleDeepLink(url)
    }

    func updateUserProperties(language: AppLanguage) {
        var attributes: [String: Any?] = [
            "platform": "ios",
            "app_language": language.bibleLanguage.rawValue
        ]

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            attributes["app_version"] = version
        }
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            attributes["app_build"] = build
        }

        Superwall.shared.setUserAttributes(attributes)
    }

    func subscriptionStatusDidChange(
        from oldValue: SubscriptionStatus,
        to newValue: SubscriptionStatus
    ) {
        apply(newValue)
    }

    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        if case .freeTrialStart = eventInfo.event {
            NotificationCenter.default.post(name: .oranteFreeTrialStarted, object: nil)
        }
    }

    private func apply(_ status: SubscriptionStatus) {
        let state: EntitlementState
        let plusIsActive: Bool
        switch status {
        case .unknown:
            state = .unknown
            plusIsActive = false
        case .inactive:
            state = .inactive
            plusIsActive = false
        case .active(let entitlements):
            state = .active
            plusIsActive = entitlements.contains { $0.id == Self.plusEntitlementID && $0.isActive }
        }

        let snapshot = EntitlementCacheRules.resolve(
            status: state,
            plusIsActive: plusIsActive,
            cachedPlus: UserDefaults.standard.bool(forKey: Self.cachedPlusKey)
        )
        entitlementState = snapshot.state
        hasPlus = snapshot.hasPlus
        UserDefaults.standard.set(snapshot.cachedPlus, forKey: Self.cachedPlusKey)

        UserDefaults(suiteName: Self.appGroupID)?.set(hasPlus, forKey: Self.widgetPlusKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Notification.Name {
    static let oranteFreeTrialStarted = Notification.Name("orante.freeTrialStarted")
}
