import UIKit

/// Native "Orante+ feature" notice shown when a paid feature was requested but no paywall appeared
/// (placement not found, no audience, error or offline). Presented on the top-most view controller so
/// it also works above sheets and full-screen covers (timer, player, Settings).
enum PremiumLockedNotice {
    static var title: String {
        AppLanguage.localized("Orante+ feature", defaultValue: "Orante+ feature")
    }

    static var message: String {
        AppLanguage.localized("Available with an Orante+ subscription.", defaultValue: "Available with an Orante+ subscription.")
    }

    static func present() {
        guard let presenter = topViewController(), !(presenter is UIAlertController) else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppLanguage.localized("OK", defaultValue: "OK"), style: .cancel))
        presenter.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
