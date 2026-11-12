# App Store submission

What a submission of PurgeQuest 1.0.0 needs, what the repository already guarantees, and what only the
owner can do. Each claim below names where it is enforced; if no check is named, it was read from the
source and not otherwise verified.

- [`REVIEW_NOTES.md`](REVIEW_NOTES.md): text for the App Review notes field, and how a reviewer can exercise the app.
- [`PRIVACY.md`](PRIVACY.md): the answers for the privacy nutrition label, and what a privacy policy must say.
- [`SCREENSHOTS.md`](SCREENSHOTS.md): the screenshot set and how to capture it.

## Already true, and kept true by CI

| Requirement | State | Enforced by |
|---|---|---|
| No network use, no third-party code | The app and widget call no networking API and have no package dependencies | `tools/ci/repo_guard.py` (1, 2) |
| Deletion is recoverable | Only `PHAssetChangeRequest.deleteAssets`, from one file; Photos moves items to Recently Deleted | `repo_guard.py` (3) |
| Privacy manifest | App and widget each ship `PrivacyInfo.xcprivacy`; every required-reason API in the sources has a declared reason | `repo_guard.py` (12) |
| Purpose strings | `NSPhotoLibraryUsageDescription` is set as a build setting. The app never adds to the library, so it declares no add-only string | read from `project.pbxproj`, `repo_guard.py` (3) |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO`. The only cryptography is SHA-256 hashing of file prefixes to find exact duplicates | read from `project.pbxproj` and `PhotoLibraryService.contentHash` |
| In-app purchase products | Six products; the local StoreKit file and the code agree on IDs and kinds | `repo_guard.py` (10) |
| Widget and app agree | Same App Group in both entitlements and both targets, same snapshot key and fields, same version | `repo_guard.py` (11, 13) |
| Restore purchases | The Armory tab has a Restore button (`StoreKitService.restore`) | read from `ShopView.swift` |

## Blocks submission: only the owner can close these

1. **Art licenses.** `docs/CREDITS.md` records the Forest Spirit pets (Bluebell, Mossy, Ember, Sunny Sprout) as having **no known author or license**, and the Craftpix wraiths as needing their terms confirmed. Separately, the 27 hero art packs and the 80 staves and shields under `ios/PurgeQuest/Art/` are not in `CREDITS.md` at all: record where each came from and under what license, or replace them. Shipping art without a license is the one item here that can get an app removed after release.
2. **Signing.** `DEVELOPMENT_TEAM` is blank. Set the team, register `com.purgequest.app` and `com.purgequest.app.purgequestwidget`, and provision the App Group `group.com.purgequest.app` for both.
3. **App Store Connect products.** Create the six in-app purchases with exactly the IDs in `StoreKitService.ProductID`, with prices and review screenshots. They exist today only in the local StoreKit file.
4. **Privacy policy URL.** Required for every app. `PRIVACY.md` lists what it has to say.
5. **A device pass.** Nothing in this repository has been run on an iPhone by the sessions that wrote it. Work through "Device test pass" in `ios/README-SETUP.md`, including iPad compatibility mode (Apple reviews iPhone-only apps on iPad too).
6. **LICENSE.** The copyright line names "the PurgeQuest authors". Put the legal owner there.

## Decide before submitting

| Item | What was found | Options |
|---|---|---|
| Live Activities | `CombatLiveActivityService` requests an activity, but the widget extension declares no `ActivityConfiguration` and the app has no `NSSupportsLiveActivities` key, so nothing ever appears. The request fails quietly. | Ship 1.0 without it and do not mention Dynamic Island in the listing (the state the code is in), or build the widget-side UI and test it on a device first. |
| `photos-redirect://` | Settings opens the Photos app with this URL scheme. It is not a documented API, and the button is labelled "Open Photos · Recently Deleted" though the scheme only opens Photos. | Keep and accept a small review risk; or relabel to "Open Photos"; or remove the button and leave the instruction text. |
| StoreKit file in the bundle | `Configuration.storekit` sits in the app's synchronized folder, so Xcode may copy it into the shipped app. It is inert there. | Check the archived `.app`; if present, exclude it from the target's membership. |
| Modular characters | 0 of 27 art packs are approved, so every hero renders through the legacy renderer. That is a complete, shippable state. | Ship as is, or approve wave 1 first (`docs/modular/REVIEW.md`). |
| Minimum Xcode | The sources need Swift 6.2 (`@concurrent`). | Build the release with Xcode 26 or later. |

## Listing facts

- **Category:** Utilities or Games. The app deletes photos as its function and is a game in presentation; pick the one the screenshots support.
- **Age rating:** cartoon/fantasy violence, infrequent or mild. No user-generated content, no web access, no gambling. Purchases buy named items or a fixed number of gems; nothing bought is random.
- **Device support:** iPhone, portrait, iOS 18.0 or later.
- **On-device generated text:** on iOS 26 with Apple Intelligence available, a one-line taunt per monster comes from the system's on-device model (`FoundationFlavorService`); otherwise fixed strings are used. Nothing is sent anywhere.
