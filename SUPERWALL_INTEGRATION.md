# Superwall integration

Integrated on 14 October 2026 using the native iOS SDK and the default Superwall purchase controller.

- [x] Detect platform (`ios`)
- [x] Determine purchase controller path (`default`, no existing purchase system)
- [x] Install SDK dependency (SuperwallKit 4.17.0 via Swift Package Manager)
- [x] Configure Superwall at app launch
- [x] User management (anonymous by default; UUID-based `identify` and `reset` APIs exposed)
- [x] Feature gating (placements registered)
- [x] Track subscription state
- [x] Set user properties
- [x] In-app paywall previews (existing `zensounds://` scheme routed to Superwall)
- [x] Post-integration: deep links, analytics, feature gating audit

## Registered placements

| Placement | Feature | Parameters |
| --- | --- | --- |
| `play_sound` | Start or switch a sound | `sound_id`, `source` |
| `create_mix` | Open the mix editor | `source` |
| `bible_narration` | Start verse narration | `book`, `chapter`, `verse` |
| `guided_rosary` | Start guided Rosary narration | `mystery_set` |

Until a placement is attached to a campaign, Superwall executes the feature closure immediately. Configure a paywall's Feature Gating option in the dashboard before relying on it to restrict access.

## Dashboard actions

1. In Superwall Settings → General, set the Apple Custom URL Scheme to `zensounds`.
2. Create campaigns for the placements above and explicitly choose Gated or Non Gated behavior.
3. Create App Store products and attach them to paywalls.
4. Test purchases and restoration with a sandbox account.
5. Universal links for Web Checkout remain pending because no Web Paywall Domain was supplied. Once available, add its `applinks:` Associated Domain.

## Identity and attributes

The app has no account/login system, so Superwall's anonymous UUID remains authoritative. If authentication is added, call `SuperwallService.shared.identify(userID:properties:)` with a stable backend UUID after login and `resetUser()` on logout.

Current attributes are `platform`, `app_language`, `app_name`, `app_version`, and `app_build`. No email, advertising identifier, device identifier, or profile data is sent.

## Subscription and analytics

`SuperwallService.isSubscribed` follows `subscriptionStatusDidChange` and is available for UI state. It is not used to bypass placements; campaign audiences and feature-gating rules remain the source of access decisions.

No third-party analytics SDK was found, so Superwall events are not forwarded. Add a `SuperwallDelegate.handleSuperwallEvent` bridge only if an analytics provider is introduced.

## Privacy

SuperwallKit includes its own privacy manifest. It declares no tracking, File Timestamp reason `C617.1`, and Purchase History collection for App Functionality, not linked to the user. The App Store Connect privacy answer must be reviewed and can no longer be assumed to be “Data Not Collected”.

## Verification

- Build-for-testing: passed with zero build warnings.
- Tests: two initial runs returned `No result` for all 48 tests; after the final rebuild, the runner executed and passed all 48 tests (0 failures).
- Simulator: app launched and remained running; tapping Chuva registered `play_sound`, Superwall logged `event_not_found` because no dashboard campaign exists, and the feature closure opened the active player normally.
- Runtime limitations: the simulator had no StoreKit account and could not reach `subscriptions-api.superwall.com:443`, so remote configuration and purchases were not verified. Superwall also warned that AdSupport was not imported; this is intentionally not added because the app does not use advertising attribution or tracking.
- Paywall presentation and purchase flow require campaigns/products in the Superwall dashboard and a sandbox/TestFlight device.

## Orante+ product split (2026-10-14)

The app now uses entitlement `plus` and a single `PremiumGate`. Free sounds (`Rain`, `Forest`, `Stream`), the `good-shepherd` soundscape, Daily Word narration, preset timers/default fade, and the Terracotta widget theme never register a paid placement. Paid actions register one of:

| Placement | Dashboard mode | Parameters |
| --- | --- | --- |
| `premium_sound` | Gated | `sound_id` |
| `premium_soundscape` | Gated | `soundscape_id` |
| `create_mix` | Gated | `source`: `library`, `player`, `home`, `saved_mix` |
| `bible_narration` | Gated | `book`, `chapter` |
| `guided_rosary` | Gated | none |
| `custom_timer` | Gated | none |
| `widget_theme` | Non Gated | none |
| `onboarding_end` | Non Gated | none |
| `settings_upgrade` | Non Gated | none |

Remove or leave `play_sound` without a campaign; the app no longer registers it. Recommended audience for gated placements: users whose `plus` entitlement is inactive. `onboarding_end` targets first-run users; `settings_upgrade` and `widget_theme` target non-subscribers.

Create one subscription group named **Orante+** and map both products to entitlement `plus`:

- `com.juliocezar.zensounds.plus.annual`: R$ 69,90 / US$ 29.99 yearly, 7-day free introductory offer, Family Sharing enabled. Display: “Orante+ Anual” / “Orante+ Annual”; description: “Acesso anual a todos os recursos do Orante+.” / “Annual access to every Orante+ feature.”
- `com.juliocezar.zensounds.plus.monthly`: R$ 12,90 / US$ 4.99 monthly, no trial, Family Sharing enabled. Display: “Orante+ Mensal” / “Orante+ Monthly”; description: “Acesso mensal a todos os recursos do Orante+.” / “Monthly access to every Orante+ feature.”

The remote paywall must display price and billing period, post-trial price, trial duration, restore purchases, Terms, and Privacy links. Upload a review screenshot showing that complete paywall. Keep the custom URL scheme `zensounds`.

`Orante.storekit` contains the local products and trial. Its JSON was validated, but this environment exposes no safe scheme editor; select it manually in **Scheme > Edit Scheme > Run > Options > StoreKit Configuration** before simulator purchase tests.

### Privacy label

Superwall's current official guidance requires **Purchases > Purchase History**, purposes **Analytics** and **App Functionality**, not used for tracking. Its packaged manifest declares Purchase History for App Functionality, not linked, and no tracking; the dashboard guide additionally requires Analytics. The SDK also processes an anonymous app user UUID, vendor ID, device/app/locale attributes, paywall interaction events, and purchase/subscription state. The app sends only `platform`, `app_language`, `app_version`, and `app_build`; the previous `app_name` attribute was removed and no person's name, email, advertising ID, or login identifier is sent. Follow Superwall's label guidance: don't mark purchase history as linked to identity for this anonymous-only integration and don't enable tracking.

The privacy policy must name Superwall as a processor for paywall analytics/subscription functionality, Apple/StoreKit as the payment processor, local/App Group preferences, the anonymous identifier/device attributes and purchase events, retention/deletion contact, and state that no advertising tracking occurs. The in-app URL is `https://jcapps.dev.br/orante/privacidade` and must be live before review. Settings > Orante+ also links to Support at `https://jcapps.dev.br/orante/suporte`; Terms use Apple's standard EULA.

### Sandbox / TestFlight route

Test annual trial, monthly purchase, cancellation, accelerated expiry/downgrade, restore on a second device, Family Sharing, and cold launch offline while subscribed. Also verify the local trial reminder, native subscription-management sheet, every dashboard campaign, paywall close returning to the previous state, and the widget falling back to Terracotta after downgrade.
