# Lite subscriptions: owner setup and release checklist

Implementation is committed, but Apple sandbox and production purchases must be validated before release. No real purchase has been made by the coding environment.

## What ships

- New Free accounts: 20 screenshots per calendar month, 7-day retention.
- Existing free users at migration time: retain 200/month, including after a later downgrade.
- Lite: 500 per calendar month, 30-day retention, no watermark, no scheduled monitors.
- Allowances reset on the first of the month at 00:00 UTC, including annual subscribers. No rollover, no reset on upgrade/restore, web and iOS share usage.
- Suggested Apple Bulgaria prices: EUR 2.99 monthly / EUR 24.99 yearly. Apple determines local prices; the app displays Product.displayPrice. The existing website price system is USD; optional Lite Stripe prices must match that system (USD 2.99/24.99), not EUR price IDs.
- No ads are included. Do not advertise ad removal as a current benefit.
- Apple subscription renewal/refund state is fetched from Apple's authenticated HTTPS Server API. Client claims never grant access. Notification bodies are lookup hints only and are independently checked with Apple.
- Monthly/yearly are one subscription level. Family Sharing and Billing Grace Period are not supported in this initial integration; leave both OFF.

## 1. Cloudflare database first

Apply `screenshot-tool/migrations/0011_apple_lite.sql` ONCE before deploying the backend. It snapshots existing free users at 200 and gives newly created accounts a default of 20. Do not rerun its UPDATE later: that would grandfather new accounts too. Prefer Wrangler migration tracking. If using the Cloudflare console, execute each statement separately and keep a record that 0011 was applied.

No existing captures are deleted by this migration. Existing plan retention is unchanged.

## 2. App Store Connect agreements

In App Store Connect > Business, accept the Paid Apps Agreement and complete required tax and banking details. App download price remains Free.

## 3. Create subscriptions

Apps > Easy Screen Capture > Monetization > Subscriptions. Create group `Easy Capture Lite`.

| Reference name | Product ID | Duration |
| --- | --- | --- |
| Lite Monthly | `com.easyscreencapture.ios.lite.monthly` | 1 month |
| Lite Yearly | `com.easyscreencapture.ios.lite.yearly` | 1 year |

Use the SAME subscription level for both. Add English group/display names, product descriptions, availability, local prices and a review screenshot of the Lite screen. Suggested concise description: `500 screenshots each calendar month. No watermark. 30-day cloud history.` Check Apple's field length limits as you enter it.

Keep Family Sharing and Billing Grace Period disabled. Don't add a free trial in this first release.

## 4. Generate the correct Apple key

Users and Access > Integrations > Keys > In-App Purchase > +. Name it `Easy Capture Server`. Download the .p8 once and securely store it. Copy Key ID and Issuer ID. This is a different key from the APNs push-notification key.

In Cloudflare > Workers & Pages > screenify > Settings > Variables and Secrets, add:

| Secret | Value |
| --- | --- |
| `APPLE_IAP_KEY_ID` | In-App Purchase Key ID |
| `APPLE_IAP_ISSUER_ID` | App Store Connect Issuer ID |
| `APPLE_IAP_PRIVATE_KEY` | Entire downloaded .p8 including BEGIN/END and line breaks |
| `APPLE_IAP_WEBHOOK_SECRET` | A new random secret, e.g. output of `openssl rand -hex 32` |

Never put the .p8 in GitHub, the app bundle, or chat. The bundle ID is fixed in code to `com.easyscreencapture.ios`.

## 5. Register server notifications

In the app's App Information, set App Store Server Notifications production and sandbox URLs to:

`https://easyscreencapture.com/api/billing/apple-notifications?key=YOUR_RANDOM_WEBHOOK_SECRET`

Select Version 2. Substitute the secret from step 4; keep the URL private. Configure access logging to redact that query parameter. The endpoint uses the secret as an initial gate, then fetches authoritative status from Apple before updating access. It does not trust notification payload claims. An hourly reconciliation job is also enabled; refunds and renewals can be delayed if notifications fail. At scale, increase reconciliation capacity; currently 50 subscriptions are checked per hourly batch, with due-account refresh on mobile profile requests.

## 6. Sandbox accounts

Create a dedicated Easy Capture Free account and verify its email. Find its ID in D1:

```sql
SELECT id, email, plan, free_quota FROM users WHERE email_lower = 'your-test-email@example.com';
```

Set Cloudflare `APPLE_SANDBOX_USER_IDS` to that user ID. For multiple test/review accounts, use comma-separated IDs. Only these accounts can activate Sandbox transactions on this backend. Do not add normal customers. Include the App Review purchase-test account in this allowlist before review.

Create an Apple Sandbox tester in App Store Connect > Users and Access > Sandbox, if testing through Xcode. TestFlight uses Apple's sandbox without charging real money. The Easy Capture account and Apple testing account are separate identities.

## 7. Deploy and rebuild

Deploy/promote the backend AFTER migration. Keep hourly cron `0 * * * *`.

On the Mac:

```bash
git pull --ff-only
xcodegen generate
open EasyCapture.xcodeproj
```

Regeneration is required because App/Purchases.swift is new. Team R4ZW9JZQ6L is now in project.yml so regeneration preserves the intended team. Confirm signing for both app and extension. Build number is 2; increment if that build number was already uploaded. Add In-App Purchase capability to the main target in Xcode if needed. No purchase capability is needed on the share extension.

Do not use an Xcode local StoreKit configuration to test server verification: local transactions do not exist in Apple's Server API. Use Sandbox or TestFlight.

## 8. Required tests before release

- New account shows quota 20; old free account still shows 200.
- You > Explore Lite loads monthly and yearly prices from Apple.
- Purchase monthly; quota becomes 500 minus already-used monthly captures, and retention becomes 30 days on both web and iOS.
- Restore on a second device with the SAME Easy Capture account; access is restored without a second charge.
- Restore with a DIFFERENT Easy Capture account; purchase must not transfer.
- Cancel Apple's purchase sheet; free account remains free.
- Test Ask to Buy/pending if supported; never grant before approval.
- Simulate provider/network failure after purchase; Restore purchases retries delivery. App finishes transactions only after server acknowledgment.
- Test sandbox renewal, expiry, cancellation, refund and monthly/yearly switching. Cancellation keeps access until expiry; refund removes it after server refresh.
- Existing Stripe-paid accounts must not get another buy button. Stripe checkout is blocked while Apple access is active. Do not manually create overlapping subscriptions; cross-provider upgrades require cancellation/expiry first.
- Apple account deletion warning links to Apple subscription management. Deleting the Easy Capture account DOES NOT cancel Apple billing automatically.
- Check logs for `[apple]` failures and ensure the notification URL secret is not retained in logging.

Backend automated tests use mocked Apple HTTPS responses and real SQLite/WebCrypto. They do not replace Sandbox, production credentials, UI tests or App Review.

## 9. Submit together

Attach the first two subscriptions to the app version's In-App Purchases and Subscriptions section and submit them with the build. Supply review screenshots and notes. Give reviewers a verified free account for purchase testing and, if needed, a separate account with monitoring access. Update App Privacy to reflect linked purchase history and account identifiers. Include Apple's standard EULA URL in the description. Review the updated release/APP_STORE.md and release/PRIVACY_WORKSHEET.md.

## Optional website Lite checkout

The shared Lite entitlement is available on the website immediately after an Apple purchase. Selling Lite through Stripe additionally requires creating matching USD recurring prices and setting `STRIPE_PRICE_LITE_MONTHLY` / `STRIPE_PRICE_LITE_YEARLY`. Existing paid Stripe plans continue working without new price IDs. Validate website checkout separately before advertising it.

## References

- https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/
- https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/generate-keys-for-in-app-purchases/
- https://developer.apple.com/documentation/appstoreserverapi/get-all-subscription-statuses
- https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox
