# Review account and release gates

## Review account preparation

1. Create a dedicated account using an inbox you control. Do not reuse a personal/customer account. Its address and password belong only in your password manager and App Store Connect.
2. Complete email verification. Confirm login works in the native app.
3. Ensure the account has monitor access and sufficient capture allowance through the existing entitlement system. Do not create fake Stripe subscription IDs or ask Apple to purchase a plan.
4. Capture 3–5 non-sensitive pages you own, in varied desktop/mobile viewports. Use recognizable page titles and no customer data.
5. Create one visual monitor on a page you can edit. Establish its baseline, make a visible edit, then run Check now to create a changed result and before/after pair. Keep a second unchanged result to demonstrate the filter.
6. Check the same content appears in the app, and the monitor history is separate from the regular library.
7. Enter the credentials in App Store Connect's sign-in-required fields. Keep the account active and allowance available during review. If you test account deletion, use a different disposable account.

No review account has been provisioned by this pack: production account access and control of the verification inbox are required.

## Acceptance matrix

Record build number, device, OS, date and result. A blank box means unverified, not passed.

- [ ] iPhone: install, registration, verification/resend, sign-in and session restoration.
- [ ] iPad: layout, portrait/landscape, forms and navigation.
- [ ] Capture: desktop/mobile/tablet, full-page/visible PNG, loading and failure states.
- [ ] Library: manual captures only in regular collection; monitor album contains correct history.
- [ ] Capture detail: Photos permission, save, native share and deletion.
- [ ] Safari extension: share URL, then open main app and capture.
- [ ] Monitors: create, establish baseline, run now, change filter, compare, pause/resume, schedule, delete.
- [ ] Account: allowance, sign-out, relaunch; no other user's data after switching accounts.
- [ ] Disposable account: password confirmation and permanent deletion.
- [ ] Failure handling: offline launch, network interrupted during capture, expired session.
- [ ] Accessibility: large text, VoiceOver, light/dark appearance, navigation controls reachable.
- [ ] Support and privacy URLs open publicly; support mailbox receives mail.

## Push — physical device and TestFlight

Configure identifiers, migration and secrets using ../PUSH_SETUP.md. Run these checks on both Debug (sandbox) and TestFlight (production):

- [ ] Explicit opt-in succeeds and the account screen confirms registration.
- [ ] Establish baseline on a controlled page; no false change alert.
- [ ] Put app in background, make a visible page change, run Check now from website; receive alert.
- [ ] Tap opens the matching monitor album; foreground alert also behaves correctly.
- [ ] Disable push, trigger a new change, confirm no new alert for that device.
- [ ] Sign out online and confirm later changes do not target that session. Already-in-flight alerts may still arrive; opening content must require authorization.
- [ ] Deny notification permission, then recover using iOS Settings.
- [ ] No-change and below-threshold runs produce no change alert.

APNs accepted status is not proof that the user saw an alert. Check Focus and system permissions. Checks consume ordinary account allowance.

## Submit only when

- [ ] Apple membership active; both app targets signed by the correct team.
- [ ] Backend changes promoted to production; migration and APNs secrets configured.
- [ ] Upload uses normal App Store Connect distribution, not TestFlight Internal Only.
- [ ] Uploaded TestFlight build passes the matrix, including production push.
- [ ] Real iPhone and iPad screenshots supplied; listing reflects the tested build.
- [ ] Review account, contact fields, privacy answers, age rating and business declarations complete.
- [ ] Correct build selected, manual release selected, Add for Review and then Submit for Review completed.

For each later upload increment CURRENT_PROJECT_VERSION in project.yml and regenerate. Keep private keys, credentials and signed provisioning material out of this repository.
