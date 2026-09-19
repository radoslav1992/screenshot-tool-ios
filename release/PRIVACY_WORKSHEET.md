# App Privacy worksheet

This is a code-based inventory for the owner to confirm, not a completed App Store Connect declaration. Include production backend and third-party handling. The app's privacy manifest does not replace App Store Connect answers.

| Data in the implementation | Apple category to assess | Purpose / linkage |
| --- | --- | --- |
| Registration email and display name | Contact Info: Email Address, Name | App Functionality; linked to account |
| Account ID and authenticated session | Identifiers: User ID | App Functionality/security; linked |
| APNs device token and registration | Identifiers: Device ID | App Functionality; linked; optional notifications |
| Submitted URLs, monitor labels/settings | User Content: Other User Content | App Functionality; linked |
| Generated screenshot images | User Content: Photos or Videos | App Functionality; linked; not access to the user's existing photo library |
| Capture activity, quota counters, check history | Usage Data: Product Interaction / Other Usage Data | App Functionality; linked; assess exact categories in form |
| Capture timing/failure and push delivery status | Diagnostics: Performance Data / Other Diagnostic Data | App Functionality; linked where stored against an account |
| Apple original transaction ID, product, expiry and existing web plan | Purchases: Purchase History | App functionality; linked to account |
| Random appAccountToken shared with Apple | Identifiers: User ID | Links verified purchases to the signed-in account |
| Support correspondence | User Content: Customer Support | Confirm collected support data and optional-disclosure criteria |
| Cloudflare request/security logging | Relevant identifiers or diagnostics depending on actual retention/use | Confirm deployed logging settings and provider processing |

The native app has no advertising/analytics SDK or cross-app tracking implementation. Confirm production integrations before answering Tracking = No. Do not mark the whole app as collecting no data. Card entry is not part of the native app; Stripe checkout belongs to the website.

The current privacy manifests are not a substitute for this full server-side inventory. Reconcile the final declaration and manifests with actual production processing before submitting. Do not declare a category merely because it appears in this worksheet if it is not actually collected under Apple's definition.

Public policy: https://easyscreencapture.com/privacy
Public support: https://easyscreencapture.com/support

Verify both URLs after Cloudflare promotion. Confirm support inbox receipt separately from outbound email setup.

Source and definitions: https://developer.apple.com/app-store/app-privacy-details/
