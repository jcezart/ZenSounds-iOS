import Foundation

@MainActor
final class OnboardingState {
    static let shared = OnboardingState()
    static let seenKey = "orante.onboarding.seen.v1"

    private let defaults: UserDefaults
    private(set) var isSuppressedForDeepLink = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldPresent: Bool {
        !defaults.bool(forKey: Self.seenKey) && !isSuppressedForDeepLink
    }

    func suppressForCurrentLaunch() {
        isSuppressedForDeepLink = true
    }

    func markSeen() {
        defaults.set(true, forKey: Self.seenKey)
    }
}

enum TrialReminderRules {
    static func reminderDate(startedAt: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: 5, to: startedAt)
    }
}

extension Notification.Name {
    static let oranteDeepLinkReceived = Notification.Name("orante.deepLinkReceived")
}
