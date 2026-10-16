import SwiftUI

/// The single Orante+ lock used on every paid entry point. Visibility is decided centrally by
/// `PremiumGate.shouldShowBadge`: shown only to confirmed non-subscribers (never while the entitlement is
/// `.unknown`) and never for free features such as the Word of the Day.
struct PremiumLockBadge: View {
    enum Style {
        /// Accent lock on a soft accent circle, for rows, buttons and toolbars.
        case standard
        /// White lock on a dark translucent circle, for artwork; place it in the top-trailing corner.
        case overlay
    }

    let feature: PremiumFeature
    var style: Style = .standard

    @ObservedObject private var superwall = SuperwallService.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        if superwall.premiumGate.shouldShowBadge(for: feature) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(style == .overlay ? Color.white : palette.accent)
                .frame(width: 22, height: 22)
                .background(
                    style == .overlay ? Color.black.opacity(0.45) : palette.accent.opacity(0.12),
                    in: Circle()
                )
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Requires Orante+")
        }
    }
}

extension View {
    /// Top-trailing lock over artwork (sound images, soundscape cards, mix circles).
    func premiumLockOverlay(for feature: PremiumFeature, padding: CGFloat = 8) -> some View {
        overlay(alignment: .topTrailing) {
            PremiumLockBadge(feature: feature, style: .overlay)
                .padding(padding)
        }
    }
}
