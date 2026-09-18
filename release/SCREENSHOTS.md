# Real App Store screenshots

Final product screenshots have not yet been captured. This Linux workspace cannot run the iOS simulator; the existing CI registration attachment alone does not show the product's core features. Use the actual app on your Mac with a prepared account. No generated/mock UI is needed.

## Capture sizes

Use an iPhone 16 Pro Max simulator (1320 x 2868 portrait) and a 13-inch iPad Pro simulator (2064 x 2752 portrait), or another currently accepted size. The app supports both device families. Capture each layout independently; do not stretch an iPhone screen into an iPad image.

Apple's current specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Ordered shot list

| Filename | Screen to open | Optional marketing headline |
| --- | --- | --- |
| 01-capture.png | Capture form, a public page you own, viewport selected | Capture the web. Keep the details. |
| 02-library.png | Regular Library with several completed captures | Your visual library, organized. |
| 03-monitors.png | Monitor albums with meaningful labels | A home for every website you follow. |
| 04-history.png | A monitor's recent changed and unchanged checks | See what changed over time. |
| 05-comparison.png | Before/after view with a real visible change | Review the difference. |

The raw screenshots are suitable to upload if their sizes are accepted. Headlines are optional design copy, not instructions to alter the app UI. Avoid personal account screens, real customer content, loading spinners, failed checks and keyboards obscuring the feature. Use accurate sample content you own.

## On your Mac

1. Pull main, run xcodegen generate, open EasyCapture.xcodeproj and run the app on the chosen simulator.
2. Sign in using the prepared account; navigate to the first screen above.
3. Get the simulator UDID using xcrun simctl list devices booted.
4. Run bash scripts/capture-store-screen.sh YOUR_SIMULATOR_UDID iphone 01-capture.
5. Navigate to the next screen and repeat with its filename stem.
6. Run the iPad simulator and repeat with ipad instead of iphone.
7. Inspect all PNGs in release/screenshots/ at full size before uploading. Their content and dimensions must match the selected App Store Connect slots.

The helper captures the current real simulator screen; it does not sign in, alter account data or manufacture screenshots. Outputs are ignored by Git to avoid committing private screen content inadvertently. A simulator capture does not verify real-device push delivery.
