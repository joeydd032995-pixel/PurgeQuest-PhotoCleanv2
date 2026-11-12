# Privacy answers

## Nutrition label (App Store Connect > App Privacy)

**Data collection: "No, we do not collect data from this app."**

Apple's definition of *collect* is transmitting data off the device in a way that lets the developer or a third party access it. The app transmits nothing:

| Question a reviewer might ask | Answer | Where to see it |
|---|---|---|
| Does the app send photos, videos or their metadata anywhere? | No. There is no networking code in the app or the widget. | `tools/ci/repo_guard.py`, check 1, fails the build if a networking API appears |
| Analytics, crash reporting, advertising SDKs? | None. The project has no package dependencies. | `repo_guard.py`, check 2 |
| Tracking (as in App Tracking Transparency)? | No. `NSPrivacyTracking` is false in both privacy manifests. | `ios/PurgeQuest/PrivacyInfo.xcprivacy`, `ios/PurgeQuestWidget/PrivacyInfo.xcprivacy` |
| Purchases? | Handled by Apple through StoreKit. The app stores which cosmetics are owned and the gem balance on the device. The developer receives Apple's standard sales reports, which is not collection by the app. | `StoreKitService.swift` |
| Is anything stored? | Yes, on the device only: game progress, the list of recent deletions (identifier, size, date), which items were spared, and cached duplicate fingerprints (a 64-bit perceptual hash per item). Deleting the app removes all of it. Settings has a full reset. | SwiftData models in `ios/PurgeQuest/Models/` |

If any of this changes (a crash reporter, a backend, cloud sync), the label must change with it; `repo_guard.py` will fail first.

## Privacy manifest (already in the build)

| Target | Required-reason API | Reason declared | Why |
|---|---|---|---|
| App | User defaults | `CA92.1` | Settings and progress flags readable only by the app |
| App | User defaults | `1C8F.1` | The widget snapshot, shared through the App Group |
| App | Disk space | `85F4.1` | Free space is read before and after a purge to show the player how much was really reclaimed; never sent anywhere |
| Widget | User defaults | `1C8F.1` | Reads the snapshot from the App Group |

No tracking domains and no collected data types are declared, because there are none. `repo_guard.py` (check 12) fails if a source file starts using a required-reason API that its target's manifest does not explain.

## What the privacy policy has to say

A policy URL is required even for an app that collects nothing. It can be one short page that states, truthfully:

1. The app does not collect, transmit or share any personal data, and has no accounts.
2. Photos and videos are analysed on the device only. Deleting moves items to the Photos app's Recently Deleted album, from which they can be restored for 30 days.
3. Game progress and a short history of deletions are stored on the device and removed with the app.
4. Purchases are processed by Apple; the developer does not see payment details.
5. A contact address for privacy questions.
6. That the policy will be updated if any of this changes.

## Permission strings in the build

- **Photo Library (read/write):** "PurgeQuest needs access to your Photo Library so you can battle photo and video monsters and reclaim storage. Items you choose to delete are moved to Recently Deleted in Photos and can be recovered for 30 days."
The app never adds anything to the Photo Library, so there is no add-only permission string.

The string says what the access is for in plain words, which is what Guideline 5.1.1 asks.
