---
name: rork-swift-ios
description: Continue, debug, and harden native SwiftUI iOS apps originally generated or iterated with Rork. Use when working on Rork-exported Xcode projects, Swift 5 + SwiftUI offline apps, App Groups, Widgets, Live Activities, StoreKit 2, Photos access, signing teams, entitlements, rork.json, or when the user mentions Rork, Xcode, continuing an iOS app, offline SwiftUI, no third-party SDKs, or wants Xcode-ready improvements.
---

# Skill: Rork + Swift 5 + Xcode Native iOS

## Goal
Produce correct changes to this Rork-originated native SwiftUI iOS app, which targets iOS 18+ and uses Swift 5 language mode. Use a recent Xcode that supports the current source and SDK features; the minimum compatible Xcode version has not been verified. Preserve its offline-first architecture and avoid third-party SDKs unless the user authorizes them.

## Trigger
Use for any task on a project that has `rork.json`, contains Rork fingerprints (Config.swift placeholders, generated structure), or the user says "Rork", "continue the iOS app", "Xcode", "SwiftUI", "SwiftData offline", "widgets", "Live Activities", or "StoreKit".

## Inputs
- Repository path or GitHub owner/repo (prefer the live tree over README claims)
- Target change (feature, bugfix, classifier, UI, IAP, widget, etc.)
- Constraints — on-device game and analysis, no third-party analytics, recoverable deletion only, preserve saves. Photos can download iCloud media and StoreKit uses Apple services.
- Signing team / App Group needs if building

## Process
1. Read `rork.json`, top-level README, and any `docs/` design notes first. Prefer source files over README when they conflict.
2. Map the real structure — Models, Services, ViewModels, Views, Widget extension, entitlements, `.storekit` config.
3. Confirm the safety contract of the app (Photos deletion path, confirmation gates, offline promise) before any change that touches media or persistence.
4. Use the project's Swift language mode and first-party Apple frameworks. Prefer existing patterns such as `@Observable`, SwiftData, and enum-namespaced pure services. Do not assume classifier protocols exist; inspect the current source first.
5. Keep App Group sharing via duplicated Codable snapshots when the main module cannot be imported by the extension.
6. Add or extend unit tests with the Swift Testing framework for pure logic (classification thresholds, XP curves, clustering, fitting).
7. Verify signing, entitlements, and scheme configuration remain valid. Leave DEVELOPMENT_TEAM blank or document the required team.
8. Update only the parts of the README that are factually wrong if the change makes them stale; do not invent future features as done.

## Tools
- GitHub tools for tree and file contents
- Local file read/write when the repo is checked out
- Xcode project awareness (pbxproj, schemes, entitlements, INFOPLIST_KEY_*)
- Never add CocoaPods, SPM third-party packages, or network clients unless the user explicitly requests them

## Output
- Compiling Swift changes that match existing style and architecture
- Clear note of any README vs source drift discovered
- Manual QA steps for Photos, Limited Access, widgets, Live Activities, and StoreKit test config
- List of remaining TODOs that the change did not close

## Quality checks
- No permanent delete path; Recently Deleted only
- No new network or analytics
- Existing SwiftData models and saves remain loadable
- Classifier or content IDs referenced by quests/achievements/seasonals are actually reachable
- Conditional compilation for ActivityKit / FoundationModels stays correct

## Failure handling
- If Rork-generated Config.swift or build settings conflict, document the conflict and prefer the Xcode-native pattern.
- If App Group or signing fails, provide exact entitlement and team steps rather than silent workarounds.
- If a modular or asset system is mid-migration, never activate the new path for production renders until acceptance gates in the design doc are met.

## Metrics
- Change builds with a suitable current Xcode and retains the iOS 18 deployment target; report any toolchain or SDK limitations
- Pure-logic paths have or gain tests
- Privacy and offline contract preserved
- Agent can hand the project to another agent with a short, accurate state summary

## Rork-specific principles
- Rork produces real SwiftUI, not React Native wrappers. Treat the output as a normal Xcode project that can be opened, signed, and extended locally.
- Prefer Design / Plan / Build discipline — read design docs before large structural changes.
- Keep the project exportable and two-way GitHub sync friendly.
- When the user will continue in Rork later, avoid patterns that Rork cannot easily re-ingest (heavy custom build scripts, non-standard project layouts).

## References
- See `references/rork-xcode-handoff.md` for common friction points.
- See `references/apple-framework-checklist.md` for the allowed first-party surface.
