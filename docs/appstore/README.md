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
| LICENSE | Proprietary notice; the copyright line names Joseph Dabrowski | read from `LICENSE` |
| Art licenses | Every third-party pack and its terms are recorded in `docs/CREDITS.md`; the Credits screen in Settings lists them and shows the Cinzel license; the app cannot share or save the art | `repo_guard.py` (16) for the license text; the rest read from `CREDITS.md` and `SettingsView.swift` |

## Blocks submission: only the owner can close these

1. **Signing.** `DEVELOPMENT_TEAM` is blank. Set the team, register `com.purgequest.app` and `com.purgequest.app.purgequestwidget`, and provision the App Group `group.com.purgequest.app` for both.
2. **App Store Connect products.** Create the six in-app purchases with exactly the IDs in `StoreKitService.ProductID`, with prices and review screenshots. They exist today only in the local StoreKit file.
3. **Privacy policy URL.** The policy is written: [`../privacy/PRIVACY_POLICY.md`](../privacy/PRIVACY_POLICY.md). What is left is to publish it at a public web address (the repository is going private, so not from this repository) and enter that URL in App Store Connect. Re-read it against the app before submitting.
4. **A device pass.** Nothing in this repository has been run on an iPhone by the sessions that wrote it. Work through "Device test pass" in `ios/README-SETUP.md`, including iPad compatibility mode (Apple reviews iPhone-only apps on iPad too).
5. **Make the repository private before launch.** The owner decided on 13 November 2026 to keep it public until then. It holds the third-party art files (`docs/CREDITS.md`), and the licenses are clearest when they are not publicly downloadable. Private repositories get limited free CI minutes, and macOS minutes count extra, so check Settings > Billing first and consider dropping the duplicate `tour` job in `ui-snapshots.yml` (the same tour runs inside `ios.yml`).

## Decide before submitting

| Item | What was found | Options |
|---|---|---|
| Live Activities | `CombatLiveActivityService` requests an activity, but the widget extension declares no `ActivityConfiguration` and the app has no `NSSupportsLiveActivities` key, so nothing ever appears. The request fails quietly. | Ship 1.0 without it and do not mention Dynamic Island in the listing (the state the code is in), or build the widget-side UI and test it on a device first. |
| `photos-redirect://` | Settings opens the Photos app with this URL scheme. It is not a documented API, and the button is labelled "Open Photos · Recently Deleted" though the scheme only opens Photos. | Keep and accept a small review risk; or relabel to "Open Photos"; or remove the button and leave the instruction text. |
| StoreKit file in the bundle | `Configuration.storekit` sits in the app's synchronized folder, so Xcode may copy it into the shipped app. It is inert there. | Check the archived `.app`; if present, exclude it from the target's membership. |
| Armor in the Armory | Helms, chest pieces, legs and hands (the four classic helm/chest items and the 32 race armor pieces) are hidden from the shop in 1.0 (`CosmeticType.hiddenFromShop`) because the hero sprite draws only held gear. They stay in the catalog, so nothing is lost. The free Iron Helm and Purge Plate remain the default equipped items and show as badges on the Hero tab. | Bring them back once layered armor can be drawn on the hero (this needs the modular packs approved and a renderer change). |
| Modular characters | 0 of 27 art packs are approved, so every hero renders through the legacy renderer. That is a complete, shippable state. | Ship as is, or approve wave 1 first (`docs/modular/REVIEW.md`). |
| Minimum Xcode | The sources need Swift 6.2 (`@concurrent`). | Build the release with Xcode 26 or later. |
| Grok-made icons | The app icon, the emblem and the six Bestiary icons were made with Grok (xAI). By the owner's summary of xAI's terms (`docs/CREDITS.md`), the owner owns the output and may use it commercially, but xAI gives no IP indemnification and trains on what is submitted. | Skim xAI's own terms once for those lines; never upload third-party art to Grok; keep any watermark or provenance metadata. |

## Listing facts

- **Category:** Utilities or Games. The app deletes photos as its function and is a game in presentation; pick the one the screenshots support.
- **Age rating:** the owner chose 13+ to be safe. The content would likely qualify for a lower tier (cartoon/fantasy violence, infrequent or mild; no user-generated content, no web access, no gambling), so answer the App Store Connect questionnaire truthfully and, if it computes a lower rating, use the age-rating override to set 13+. Purchases buy named items or a fixed number of gems; nothing bought is random.
- **Device support:** iPhone, portrait, iOS 18.0 or later.
- **On-device generated text:** on iOS 26 with Apple Intelligence available, a one-line taunt per monster comes from the system's on-device model (`FoundationFlavorService`); otherwise fixed strings are used. Nothing is sent anywhere.
