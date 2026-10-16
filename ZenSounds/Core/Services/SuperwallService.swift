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

    #if DEBUG
    /// Debug-only override for testing paid/free flows without a sandbox purchase.
    @Published var debugPlusOverride: DebugPlusOverride {
        didSet {
            UserDefaults.standard.set(debugPlusOverride.rawValue, forKey: DebugPlusOverride.storageKey)
            publish(lastSnapshot)
        }
    }
    #endif

    private static let apiKey = "pk_Fiv1oYMGZPUzCmnAUxtZc"
    private static let plusEntitlementID = "plus"
    private static let cachedPlusKey = "orante.plus.lastConfirmedActive"
    static let appGroupID = "group.com.juliocezar.zensounds"
    static let widgetPlusKey = "plus_active"
    private var isConfigured = false
    /// Kept by reference: the SDK stores this same object, so its alert texts can follow the app language.
    private let sdkOptions = SuperwallOptions()
    /// Last entitlement resolved from the SDK/cache, before any debug override.
    private var lastSnapshot: EntitlementAccessSnapshot

    lazy var premiumGate = PremiumGate(
        entitlements: self,
        registrar: { placement, onOutcome in
            let tracker = PaywallOutcomeTracker(onOutcome: onOutcome)
            let handler = PaywallPresentationHandler()
            handler.onPresent { _ in tracker.paywallPresented = true }
            handler.onDismiss { _, result in
                if result != .declined { tracker.purchasedOrRestored = true }
            }
            // Superwall doesn't release the feature on errors (e.g. offline); report it so the
            // gate can still re-check access and explain why nothing happened.
            handler.onError { _ in tracker.deliver() }
            Superwall.shared.register(
                placement: placement.name,
                params: placement.parameters,
                handler: handler
            ) {
                tracker.deliver()
            }
        },
        waitForEntitlement: { [weak self] in
            await self?.waitForPlusAfterPurchase()
        },
        onLocked: { _ in
            PremiumLockedNotice.present()
        }
    )

    private init() {
        let cachedPlus = UserDefaults.standard.bool(forKey: Self.cachedPlusKey)
        let snapshot = EntitlementCacheRules.resolve(status: .unknown, cachedPlus: cachedPlus)
        lastSnapshot = snapshot
        hasPlus = snapshot.hasPlus
        #if DEBUG
        debugPlusOverride = DebugPlusOverride(
            rawValue: UserDefaults.standard.string(forKey: DebugPlusOverride.storageKey) ?? ""
        ) ?? .automatic
        let resolved = debugPlusOverride.resolve(state: snapshot.state, hasPlus: snapshot.hasPlus)
        entitlementState = resolved.state
        hasPlus = resolved.hasPlus
        #endif
    }

    func configure(language: AppLanguage) {
        guard !isConfigured else {
            updateUserProperties(language: language)
            return
        }

        isConfigured = true
        localizeSDKAlerts()
        let superwall = Superwall.configure(apiKey: Self.apiKey, options: sdkOptions)
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

    /// The only way to start a paid feature: the gate re-checks `hasPlus` after Superwall responds.
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

    /// Restores through Superwall and returns the alert the app still has to show, if any. When the restore
    /// fails or finds no active entitlement, the SDK already showed its own alert (localized in
    /// `localizeSDKAlerts()`), so the app stays silent to avoid a second, duplicated alert.
    func restorePurchases() async -> RestoreAlertRules.AppMessage? {
        localizeSDKAlerts()
        let result = await Superwall.shared.restorePurchases()
        apply(Superwall.shared.subscriptionStatus)
        let restored = if case .restored = result { true } else { false }
        return RestoreAlertRules.appMessage(
            restored: restored,
            sdkHasActiveEntitlement: !Superwall.shared.entitlements.active.isEmpty,
            hasPlus: hasPlus
        )
    }

    /// Superwall's own restore alert ("No Subscription Found" by default) in the app's current language.
    private func localizeSDKAlerts() {
        let restoreFailed = sdkOptions.paywalls.restoreFailed
        restoreFailed.title = AppLanguage.localized("Restore purchases", defaultValue: "Restore purchases")
        restoreFailed.message = AppLanguage.localized(
            "No active subscription was found.",
            defaultValue: "No active subscription was found."
        )
        restoreFailed.closeButtonTitle = AppLanguage.localized("OK", defaultValue: "OK")
    }

    /// After a paywall purchase the delegate update can lag behind the paywall dismissal; poll the
    /// SDK briefly so the feature opens immediately once `plus` is active.
    func waitForPlusAfterPurchase(timeout: Duration = .seconds(3)) async {
        let step = Duration.milliseconds(100)
        var waited = Duration.zero
        while waited < timeout {
            apply(Superwall.shared.subscriptionStatus)
            if hasPlus { return }
            try? await Task.sleep(for: step)
            waited += step
        }
        apply(Superwall.shared.subscriptionStatus)
    }

    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        Superwall.handleDeepLink(url)
    }

    func updateUserProperties(language: AppLanguage) {
        localizeSDKAlerts()
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
        // The cache always stores the real entitlement, never the debug override.
        UserDefaults.standard.set(snapshot.cachedPlus, forKey: Self.cachedPlusKey)
        publish(snapshot)
    }

    private func publish(_ snapshot: EntitlementAccessSnapshot) {
        lastSnapshot = snapshot
        var state = snapshot.state
        var plus = snapshot.hasPlus
        #if DEBUG
        (state, plus) = debugPlusOverride.resolve(state: state, hasPlus: plus)
        #endif
        let changed = entitlementState != state || hasPlus != plus
        entitlementState = state
        hasPlus = plus

        let widgetDefaults = UserDefaults(suiteName: Self.appGroupID)
        let widgetChanged = widgetDefaults?.object(forKey: Self.widgetPlusKey) as? Bool != plus
        widgetDefaults?.set(plus, forKey: Self.widgetPlusKey)
        if changed || widgetChanged {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// Collects Superwall presentation callbacks for one `register` call and reports a single outcome.
@MainActor
private final class PaywallOutcomeTracker {
    var paywallPresented = false
    var purchasedOrRestored = false
    private var onOutcome: ((PaywallOutcome) -> Void)?

    init(onOutcome: @escaping (PaywallOutcome) -> Void) {
        self.onOutcome = onOutcome
    }

    func deliver() {
        let callback = onOutcome
        onOutcome = nil
        callback?(PaywallOutcome(paywallPresented: paywallPresented, purchasedOrRestored: purchasedOrRestored))
    }
}

extension Notification.Name {
    static let oranteFreeTrialStarted = Notification.Name("orante.freeTrialStarted")
}
