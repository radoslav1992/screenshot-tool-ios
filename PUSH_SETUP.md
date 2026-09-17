# Enable iOS push notifications

The app and Cloudflare integration are implemented. Live delivery still requires your Apple signing configuration, the D1 migration and APNs credentials. No private key belongs in GitHub or the iOS app.

## 1. Register the app in Apple Developer

Open https://developer.apple.com/account/resources/identifiers/list and select or create the explicit App ID `com.easyscreencapture.ios`. Enable **Push Notifications** and save. The Share extension (`com.easyscreencapture.ios.share`) does not need Push Notifications. Keep the existing App Group enabled for both targets.

If you choose a different bundle ID, update `project.yml`, regenerate the Xcode project, and use exactly that same value for `APNS_BUNDLE_ID` below.

## 2. Create the APNs key

In **Certificates, Identifiers & Profiles → Keys**, create a key named **Easy Capture Push**, enable **Apple Push Notifications service (APNs)**, and download its `.p8` file. Record its **Key ID**. Get your **Team ID** from your membership details. Choose a signing key authorized for this app and both development and production environments. If Apple offers restricted key configurations, make sure the selected environments and topic include this app.

Apple's instructions: https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens/

## 3. Run the D1 migration

In Cloudflare, open the D1 database attached to the website Worker. Run each block separately. These are the only new SQL changes for push (also in `screenshot-tool/migrations/0010_mobile_push.sql`).

```sql
CREATE TABLE IF NOT EXISTS push_devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  environment TEXT NOT NULL CHECK(environment IN ('sandbox','production')),
  registered_at TEXT NOT NULL,
  UNIQUE(token, environment)
);
```

```sql
CREATE INDEX IF NOT EXISTS push_devices_user ON push_devices(user_id);
```

```sql
CREATE TABLE IF NOT EXISTS push_deliveries (
  run_id TEXT NOT NULL REFERENCES watch_runs(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL REFERENCES push_devices(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  reason TEXT,
  PRIMARY KEY(run_id, device_id)
);
```

```sql
CREATE INDEX IF NOT EXISTS push_deliveries_due ON push_deliveries(status, next_attempt_at);
```

## 4. Add Cloudflare secrets

Open **Workers & Pages → screenshot-tool → Settings → Variables and Secrets**. Add these as **Secret** values:

| Name | Value |
| --- | --- |
| `APNS_KEY_ID` | The key's identifier from Apple |
| `APNS_TEAM_ID` | Your Apple Developer Team ID |
| `APNS_PRIVATE_KEY` | Entire `.p8` text, including BEGIN/END PRIVATE KEY lines and line breaks |
| `APNS_BUNDLE_ID` | `com.easyscreencapture.ios` |

Save/deploy the settings and promote the backend version containing the push changes. Preserve your other Worker secrets and bindings. Keep the existing hourly Cron Trigger: it now also retries push rejections eligible for retry. If no credentials are set, push stays dormant and email continues normally.

## 5. Build a signed iOS app

Pull the latest iOS repository, run `xcodegen generate`, and open `EasyCapture.xcodeproj`. Select your Apple team under **Signing & Capabilities** for both targets. Check **Push Notifications** is present on **EasyCapture**, and regenerate provisioning profiles if Xcode asks.

Debug builds use the development entitlement and sandbox APNs endpoint. Release/TestFlight/App Store builds use production. Use the supplied configurations together; do not override one without the other. No background-fetch capability is required for these visible alerts.

Install on a physical iPhone. Simulator tests verify compilation and UI, not delivery using your Apple account.

## 6. Enable and test

1. Sign in and open **You → Push notifications → Enable change alerts**.
2. Allow notifications. Wait for **Change alerts are enabled on this device**.
3. Create a monitor on a page you control, using a plan that supports monitors. Run it once to establish its baseline.
4. Change that page enough to exceed the monitor's threshold, then choose **Check now**. Checks use your normal capture allowance.
5. Put the app in the background. You should receive **A monitored page changed**.
6. Tap the alert: it opens that monitor's album. Foreground alerts also show a banner.
7. Test turning push off and signing out. Delivery is bound to the authenticated session; logout and account deletion cascade token cleanup. Offline logout now asks you to reconnect rather than silently leaving a push-enabled session alive.

Push preference is per device, for all of the account's monitors. Email preferences remain independent. iOS Focus modes, notification settings and Apple delivery can affect whether a banner is shown. APNs acceptance is not proof that a person saw it.

## Troubleshooting

- **Not configured:** check all four secrets, the migration and the active Cloudflare deployment.
- **Apple could not register:** check active membership, device signing, App ID capability, entitlement and provisioning profile.
- **Denied:** use the app's **Open notification settings** button, enable alerts, return and enable again.
- **No change:** baseline checks and changes below the threshold do not send pushes.
- Use this query to inspect outcomes without displaying private device tokens:

```sql
SELECT status, reason, attempts, updated_at
FROM push_deliveries
ORDER BY updated_at DESC
LIMIT 20;
```

`accepted` means Apple accepted the request; `pending` means a rejected request will be retried on a future hourly sweep (maximum three attempts, within 24 hours). `failed` can indicate a signing/topic/environment problem: check `reason`. Correct configuration and trigger a new genuine change. `unknown` means the transport outcome could not be confirmed and is not retried automatically, avoiding duplicate alerts. Invalid/expired tokens are removed. Stale delivery records are cleaned after seven days.

Lock-screen payloads intentionally omit page URLs, labels, screenshots and captured content. The backend authorizes the monitor again when the user opens it. Notifications already handed to Apple can be in flight when a session is revoked; the app clears delivered notifications and unregisters locally on sign-out.
