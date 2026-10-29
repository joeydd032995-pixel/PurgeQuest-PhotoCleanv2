# Rork → Xcode Handoff Notes

## Typical friction
- DEVELOPMENT_TEAM is often blank; set under Signing & Capabilities.
- App Group `group.com.purgequest.app` (or project-specific) must be created under the new team for Widget and Live Activity targets.
- `Config.swift` may be an empty Rork-injected placeholder — leave it or replace with real build-time values carefully.
- README and `README-SETUP.md` frequently lag the source. Always trust Models/Services over marketing text.
- Widget extension cannot import the main app module; share state only via App Group UserDefaults + duplicated Codable snapshot types.
- StoreKit testing uses the local `.storekit` configuration file; select it in the scheme for sandbox purchases without App Store Connect products.

## Preferred patterns already used in PurgeQuest-style apps
- `@Observable` root AppState + feature ViewModels
- SwiftData ModelContainer with in-memory fallback
- A static `MonsterClassifier` over extracted media signals and fingerprints; introduce a protocol only if a concrete model integration benefits from it
- Pure enum services for deterministic game logic
- Conditional `#if canImport(ActivityKit)` and FoundationModels gates
- Room / session confirmation screens before any irreversible (even recoverable) action

## What not to do
- Do not add third-party analytics, crash reporters, or remote config without explicit user approval.
- Do not bypass Photos Recently Deleted.
- Do not force modular character rendering before the design-doc acceptance gates pass.
