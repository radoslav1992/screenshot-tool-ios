# App Store submission pack — version 1.0.0

Prepared against iOS b626807 and backend 036b409 on 18 September 2026. These are ready-to-copy drafts, not an App Store submission. Signing, live APNs, real account testing, final screenshots and owner declarations remain release gates.

## App information

| Field | Value |
| --- | --- |
| Name | Easy Screen Capture |
| Subtitle | Website captures & monitoring |
| Primary language | English (U.S.) |
| Primary category | Productivity |
| Secondary category | Utilities |
| Price | Free |
| Bundle ID | com.easyscreencapture.ios |
| SKU | easycapture-ios |
| Support URL | https://easyscreencapture.com/support |
| Privacy URL | https://easyscreencapture.com/privacy |
| Marketing URL | https://easyscreencapture.com |
| Release | Manual |

Confirm name availability. Support and updated privacy pages must be deployed and accessible before submission. Confirm hello@easyscreencapture.com receives incoming mail; domain sending onboarding alone does not configure its inbox.

## Promotional text

Capture websites, keep a clear visual history, and review monitored changes from your iPhone or iPad. Your saved captures stay connected to your account.

## Keywords

website,screenshot,monitor,compare,changes,archive,webpage,visual,history,design,review

## Description

Keep a visual record of the web, wherever you are.

Easy Screen Capture brings website capture and monitoring to your iPhone and iPad. Save a page, browse your visual library, and see what changed on the websites you follow.

CAPTURE THE PAGE YOU NEED
Enter a website address and capture a full page or its visible area. Choose a desktop, tablet, or mobile viewport and save the result as a PNG.

KEEP YOUR LIBRARY ORGANIZED
Browse your regular captures separately from monitor albums. Each monitor keeps its own visual history, so recurring checks stay together.

REVIEW WEBSITE CHANGES
Open a monitor's recent checks, filter for changes, and compare before and after captures. Create visual monitors and manage their schedules, pause them, or run a check when you need one.

GET OPTIONAL CHANGE ALERTS
Enable push notifications to hear when a monitor detects a change above its configured threshold. Tap an alert to open the relevant monitor. Email alerts can be managed separately.

SAVE AND SHARE
Save selected captures to Photos or share them using the iOS share sheet. From Safari, send a website address to Easy Capture, then open the app to capture it.

CONNECTED TO YOUR ACCOUNT
Sign in with your Easy Screen Capture account or create one in the app. Captures, monitors, and your account allowance stay in sync with the web service.

An account and internet connection are required. Capture allowances, retention, monitoring access, and available schedules depend on your account plan. Scheduled checks use your capture allowance. The first monitor check establishes a baseline; later qualifying changes can trigger alerts.

## TestFlight: What to Test

Test registration and email verification, sign-in, full-page and visible-area capture, saving and sharing, regular library versus monitor albums, monitor creation and pause/resume, before/after comparison, and optional push alerts. Test Safari sharing by sending a URL and then opening Easy Capture. Check light/dark appearance, large text, iPad rotation, loss of connectivity, and signing out. Report the device, iOS version, steps, and any error text. Use only a disposable account to test deletion.

## App Review notes

Paste the following only after the review account has been prepared and verified using [REVIEW_AND_TESTS.md](REVIEW_AND_TESTS.md):

Easy Screen Capture is a native companion to our web service. Users can register or sign in, capture websites, browse saved captures, and review monitored-page changes. The supplied review account has verified email, capture allowance, and monitoring access. No purchase is needed to test that account.

Capture: open Capture, enter a public website address, choose a viewport and capture mode, then create a capture. Library separates regular captures from monitor albums. Open a monitor to inspect its recent checks and compare available before/after captures.

Notifications are optional. Open You > Push notifications > Enable change alerts and allow notifications. A monitor's first run creates a baseline; a later change above its threshold can send an alert. An unchanged page does not send an alert. Tap an alert to open that monitor's album.

Safari extension: open a webpage in Safari, choose Share > Easy Capture, save the URL, and open the main app to review settings and capture it.

Account deletion is available under You > Delete my account, with password confirmation. This permanently deletes the account and its captures. The app has no checkout or purchase prompts. The backend will remain available throughout review.

## Owner fields — enter only in App Store Connect

- Review login email and password: create and verify a dedicated account; never commit credentials.
- Review contact: your reachable name, phone and email.
- Copyright: confirm the correct rights holder before entering it.
- Seller/legal entity and EU trader details: match the enrolled entity and actual business. The website currently identifies Digital Craft Ltd.; confirm the relationship if enrolling personally.
- Age rating/content rights/export compliance: complete based on the actual build and business; do not copy blanket answers.
- Privacy answers: use [PRIVACY_WORKSHEET.md](PRIVACY_WORKSHEET.md) and confirm production settings.

## Official references

- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/
- https://developer.apple.com/app-store/review/guidelines/

Screenshot instructions: [SCREENSHOTS.md](SCREENSHOTS.md).
