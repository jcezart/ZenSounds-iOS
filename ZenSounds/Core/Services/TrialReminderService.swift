import Combine
import Foundation
import UserNotifications

@MainActor
final class TrialReminderService: NSObject, ObservableObject {
    static let shared = TrialReminderService()

    @Published var shouldExplainPermission = false
    private var trialStartedAt: Date?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(freeTrialStarted),
            name: .oranteFreeTrialStarted,
            object: nil
        )
    }

    @objc private func freeTrialStarted() {
        trialStartedAt = Date()
        shouldExplainPermission = true
    }

    func requestAndSchedule() async {
        shouldExplainPermission = false
        guard let trialStartedAt,
              let reminderDate = TrialReminderRules.reminderDate(startedAt: trialStartedAt) else { return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = AppLanguage.localized("Your Orante+ trial ends in 2 days", defaultValue: "Your Orante+ trial ends in 2 days")
            content.body = AppLanguage.localized("If you don't want to continue, cancel in iPhone Settings.", defaultValue: "If you don't want to continue, cancel in iPhone Settings.")
            content.sound = .default
            let interval = max(reminderDate.timeIntervalSinceNow, 1)
            let request = UNNotificationRequest(
                identifier: "orante.plus.trial-ending",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification permission or scheduling errors don't affect the purchase.
        }
    }
}
