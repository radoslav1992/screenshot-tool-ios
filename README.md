# Easy Capture for iOS

A native SwiftUI companion to [Easy Screen Capture](https://easyscreencapture.com), with a distinct midnight-blue, coral and ivory visual identity. iPhone and iPad, iOS 17+. Supports light and dark system appearance, Dynamic Type and standard VoiceOver controls.

## Included

- Native email/password sign-in and registration using existing accounts.
- Server-issued session stored in device-only Keychain. No password persistence, analytics SDK or embedded billing.
- Live account allowance and email verification/resend.
- Website capture: desktop/mobile/tablet, full page/visible area, PNG.
- Paginated manual library, separate from monitor albums.
- Monitor creation, pause/resume, schedule changes, check-now and deletion.
- Album timeline with changes filter and before/after comparison. Up to 30 recent checks per monitor.
- Save images to Photos, share images through the system sheet, delete captures.
- Safari share extension: save a URL, then open the app to review settings and capture. The extension deliberately does not launch its containing app using unsupported APIs.
- Account deletion with password and destructive-action confirmation.
- Original app icon, privacy manifests, contract tests and macOS CI.

## Open and run

1. On a Mac, install Xcode and its iOS simulator, then `brew install xcodegen`.
2. Clone this repo and run `xcodegen generate` at its root.
3. Open `EasyCapture.xcodeproj` and select the **EasyCapture** scheme.
4. For simulator: select an iPhone and Run. CI also builds the app and share extension without signing.
5. For a physical device or TestFlight: select your Apple Developer team for **both** targets. Keep bundle IDs unique to your account. Register the `group.com.easyscreencapture.ios` App Group and enable it for both targets. If changing its identifier, update `APP_GROUP_IDENTIFIER` in `project.yml` and regenerate.
6. Ensure the companion backend commit is deployed (see below), then sign in with your existing account.
7. To test sharing: Safari → Share → Easy Capture → Done, then open Easy Capture.

Never commit signing certificates, provisioning profiles, App Store Connect keys or Stripe secrets.

## Backend dependency

The app uses the production origin defined in `App/API.swift`; no backend is deployed by this repository.

The matching update to `radoslav1992/screenshot-tool` adds:

- `GET /api/mobile/profile`: authenticated user, plan, verification status, quota and allowed schedules.
- `GET /api/captures?collection=regular&limit=30&offset=0`: manual library.
- `GET /api/captures?collection=monitors&watch_id=...&limit=100`: owner-scoped monitor album.
- JSON response from `POST /api/auth/logout` when the client accepts JSON; web redirects remain unchanged.

Existing login/signup, capture, watch and account deletion endpoints are reused. No new database migration is needed. Promote the corresponding Cloudflare version before running the app. Existing Stripe webhooks remain the source of subscription entitlement changes.

## Billing and release scope

This is a free companion, with no checkout, prices, upgrade buttons or purchase prompts. Purchases made independently on the website update the account used by this app. Regional upgrade-link support is not enabled in this release.

**Push notifications are not implemented in this version.** Email alerts continue through the existing monitor backend. Push needs a signed Apple app, APNs credentials, authenticated device registration/removal, server delivery and invalid-token handling; it must not be represented as working before these exist. No dummy permission prompt is shown.

Projects, team reporting, advanced monitor rules and bulk imports remain web features. Existing monitors using advanced rules can be viewed and controlled, but the mobile create form creates visual monitors.

## Validation and App Store release

GitHub Actions builds app + extension and runs contract tests on an available iPhone simulator. Linux cannot type-check SwiftUI or run Xcode, so the macOS CI result is the native build gate.

Before TestFlight/App Review, test with a real account on a signed device: registration → verify email → capture → save/share → create monitor → pause/resume → comparison → logout/relaunch → deletion using a disposable account. Check airplane mode and expired sessions, large text and dark appearance. Do not delete a real customer account during testing.

Provide Apple a review account, live backend, screenshots, support URL and privacy disclosures. Review the included privacy manifests against your actual production processing and complete App Store Connect privacy labels (including account identifiers and submitted web content). App Store approval is not guaranteed by the companion model.
