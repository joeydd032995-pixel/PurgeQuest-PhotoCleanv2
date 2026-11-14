# PurgeQuest 1.0 launch checklist

Reviewed on 14 November 2026 against `main` at `57fb954`.

**How this was checked.** CI status was read from GitHub Actions: all four workflows (iOS Unit Tests, iOS Build and
Analyze, Modular assets, Repo guard) succeeded on that commit. `python3 -I tools/ci/repo_guard.py` was run and passed.
Everything else was read from the source and `project.pbxproj`, and each item names where. **Nothing was built or
run on a device**: the review had no Xcode, and the repository's own notes say no session has run the app on an iPhone.

**Where things stand.** The product is feature-complete for 1.0 and the repository's contracts hold (offline, recoverable
deletion, StoreKit IDs, App Group, privacy manifests, licenses). What is left is (1) work only the owner can do in Apple's
systems and on a phone, (2) one in-app compliance gap, and (3) a few small, low-risk fixes.

**(new)** marks an item that was not in [`README.md`](README.md) before this review. That README's two lists
("Blocks submission", "Decide before submitting") are all included below.

---

## 1. Only the owner can close these

### Apple account and signing
- [ ] Apple Developer Program membership is active; the team is chosen.
- [ ] Signing: set `DEVELOPMENT_TEAM` on **PurgeQuest** and **PurgeQuestWidget**. The app's build settings have it blank (`""`); the widget has no such key at all. Register `com.purgequest.app` and `com.purgequest.app.purgequestwidget`, and provision the App Group `group.com.purgequest.app` for both.
- [ ] **(new)** Paid Apps Agreement accepted and bank and tax details entered. Without it the in-app purchases cannot be sold.

### App Store Connect
- [ ] Create the app record: bundle ID `com.purgequest.app`, primary language, SKU. **(new)** Confirm the name "PurgeQuest" is available before building listing assets around it.
- [ ] Create the six in-app purchases with exactly the IDs in `StoreKitService.ProductID`: `com.purgequest.gems.250`, `.1000`, `.5000` (consumable) and `com.purgequest.cosmetic.embers`, `.aurora`, `.videoSlayerBundle` (non-consumable). Each needs a display name, description, price and review screenshot, and must be attached to the 1.0 version when it is submitted. The prices in `Configuration.storekit` (0.99 / 2.99 / 9.99 / 4.99 / 4.99 / 7.99) are test values: choose the real ones.
- [ ] Publish [`../privacy/PRIVACY_POLICY.md`](../privacy/PRIVACY_POLICY.md) at a public web address (not from this repository once it is private), re-read it against the build, and enter the URL.
- [ ] **(new)** Support URL (a required field): a page that gives a way to reach you. The policy's contact is `PurgeQuestPhotoClean@outlook.com`; one small site can serve both pages.
- [ ] **(new)** App Review contact details (name, phone, email). No demo account is needed: the app has no sign-in.
- [ ] App Privacy answers: "Data not collected" ([`PRIVACY.md`](PRIVACY.md)). Age rating: answer the questionnaire truthfully and override to 13+ if it computes lower. Export compliance is already answered in the build (`ITSAppUsesNonExemptEncryption = NO`).
- [ ] **(new)** Content Rights declaration: the app contains third-party art, licensed under [`../CREDITS.md`](../CREDITS.md). Answer accordingly and keep those license pages on file.

### On a phone
- [ ] Device pass: everything under "Device test pass" in [`../../ios/README-SETUP.md`](../../ios/README-SETUP.md), including iPad compatibility mode (the app is iPhone-only, so Apple reviews it on iPad in compatibility mode).
- [ ] **(new)** Also on the device: a large library (10,000+ items), a library with iCloud "Optimize Storage" turned on (originals may be downloaded when a thumbnail is requested), Limited access and Full access, the Lock Screen widgets, a real purchase against the sandbox, VoiceOver through one room (the swipe card has an adjustable action as the non-gesture route), and the largest Dynamic Type size.
- [ ] **(new)** Run real videos through the scan, not just photos. The video rules (flicker, dark, brightness jump, motionless clip) have never been measured on real footage (README Open Items 2 and 3). A wrong monster is recoverable, but a flood of false "Dark Wraith" or "Framed Phantom" verdicts would spoil the first impression.

### Build and distribute
- [ ] **(new)** Archive a **Release** build with Xcode 26 or later and run Validate App in the Organizer. Every CI workflow builds `-configuration Debug` for the simulator with `CODE_SIGNING_ALLOWED=NO`, and none archives, so signing, widget embedding, the icon and App Store Connect's upload checks have never been exercised. CI also uses `macos-latest` with no Xcode version pinned.
- [ ] **(new)** Upload to TestFlight, test the TestFlight build itself on at least two devices for about a week, with a few outside testers if you can. Every upload needs a higher `CURRENT_PROJECT_VERSION` (it is `1` in every target now); raise it in all targets together.

### Legal and repository
- [ ] **(new, raised in priority)** Settle where the owner's updated weapon and shield art (asset pass v7, 14 November) came from. [`../CREDITS.md`](../CREDITS.md) records two open points: whether anything in it derives from the CraftPix staves and shields it replaced (if so the CraftPix terms still apply to it; if not, drop those rows and the Credits screen's matching entry in `ThirdPartyCredits.swift`), and whether CraftPix art was ever uploaded to an image generator as a reference, which CraftPix forbids.
- [ ] Skim xAI's own terms once for the Grok points in `CREDITS.md` (no indemnification, they train on submissions, do not strip provenance marks).
- [ ] Re-read the CraftPix, Mica and LumioLab terms ([`../CREDITS.md`](../CREDITS.md) says to do this before each release). Ask Mica whether the original files may be re-shared, since the page does not say.
- [ ] Make the repository private (the owner's 13 November decision was "before launch"). Note that the converted third-party art is publicly downloadable until then, which is the exposure the licenses are about; closing it earlier costs only CI minutes. Check Settings > Billing first and consider dropping the duplicate `tour` job in `ui-snapshots.yml`.

---

## 2. Small fixes in the repository

- [ ] **(new) Link the privacy policy inside the app, and give a way to contact you.** Apple asks for the policy link in the app as well as in the store metadata (Guideline 5.1.1(i)). Settings > Privacy (`SettingsView.swift:133`) is text only, and no file under `Views/` contains a URL or an email address. Add the policy link and a support link or mail address to Settings > About. Needs the URLs from section 1.
- [ ] **(new) Say honestly what "freed" means.** Items go to Recently Deleted and stay there for 30 days, so their size is not free space yet. The Dashboard already separates "Pending deletion" from "Actually reclaimed" (`DashboardView.swift:105-150`), but other places show the sum of file sizes as freed with no such caveat: "Storage freed" on the combat summary (`CombatView.swift:256`, `:322`), "Total freed" in Settings and on the Hero tab, "reclaimed" on the Bestiary family page, and the screenshot caption "See what you have freed" in `SCREENSHOTS.md`. Relabel (for example "Moved to Recently Deleted") or add one line of explanation. Otherwise the first review that says "it didn't free any space" is accurate.
- [ ] **Keep `Configuration.storekit` out of the shipped app.** Confirmed in `project.pbxproj`: the only exception in the synchronized groups is the widget's `Info.plist`, so the file is a member of the app target. Exclude it from the target (or check the archived `.app`).
- [ ] **Decide `photos-redirect://`** (`SettingsView.swift:121`). It is an undocumented URL scheme, and the label promises more than it does. Recommended: remove the button and keep the instruction text, which removes the review risk at almost no cost.
- [ ] **Live Activities: ship without them.** Confirmed: nothing under `ios/` declares an `ActivityConfiguration` or `NSSupportsLiveActivities`, and `CombatLiveActivityService` fails quietly. Do not mention Dynamic Island or Live Activities in the listing or screenshots. Removing the service and its calls in `CombatViewModel` can wait for 1.0.1.

---

## 3. Listing (none of this is drafted in the repository yet)

- [ ] Name and subtitle (30 characters each).
- [ ] Description, keywords (100 characters), promotional text. The line to lead with: nothing is deleted without two confirmations, and everything goes to Recently Deleted.
- [ ] Category: Utilities or Games, whichever the screenshots support.
- [ ] Copyright line (for example "2026 Joseph Dabrowski", matching `LICENSE`).
- [ ] Six screenshots per [`SCREENSHOTS.md`](SCREENSHOTS.md), from photographs you own. The Room Summary and duplicate-group card are not in the automated tour, so capture those two by hand.
- [ ] Paste the block from [`REVIEW_NOTES.md`](REVIEW_NOTES.md) into the review notes after checking the tab and button names against the build you submit.

---

## 4. Ship knowingly (decided or documented; no work needed)

- [ ] Helms, chest, legs and hands are hidden everywhere in 1.0 (`hiddenFromShop`, `hiddenFromHero`); weapons, shields, skins, pets and effects are shown.
- [ ] 0 of 27 modular packs approved, so every hero uses the legacy renderer, a complete state. Approving wave 1 is optional and is a person's job (`docs/modular/REVIEW.md`).
- [ ] Known weak spots in [`../../README.md`](../../README.md) "Open Items" (an ordinary photo can be named a Blur Beast, the Shaky Ghost measures a brightness jump rather than shake, duplicates are found within a dive's 150 items, no Core ML model). None blocks 1.0.
- [ ] Age rating 13+ and the on-device-only, no-network position are final.

---

## 5. Launch and after

An App Store release cannot be rolled back, so decide the response in advance.

- [ ] Release manually after approval, with **phased release** on, so the first week reaches a fraction of users.
- [ ] There is no crash reporter by design. Watch Xcode Organizer (Crashes, Energy) and App Store Connect (ratings, sales, purchases) daily for the first week, and the support inbox.
- [ ] Pull from sale and ship an expedited fix if any of these appears: an item deleted without both confirmations; a crash at launch or in the combat loop; a purchase taken and not delivered; a widget crash.
- [ ] Candidates for 1.0.1 and later: a neutral monster for "no signal" photos, Live Activities, the armor layers and modular approvals, duplicates across the whole library, a Core ML blur model, localization (the app is English only).
