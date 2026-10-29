---
name: widgetkit-snapshot-hygiene
description: Keep WidgetKit and App Group snapshots consistent, small, and safe between the main app and widget extension. Use when working on WidgetSnapshotService, SharedSnapshot, App Group UserDefaults, Home Screen or Lock Screen widgets, timeline reloads, widget data not updating, or any cross-process state sharing in a SwiftUI iOS app.
---

# Skill: WidgetKit Snapshot Hygiene

## Goal
Maintain a single, small, Codable snapshot that both the main app and the widget extension can read and write via an App Group, without module import issues, without stale data, and without leaking large media or sensitive content.

## Trigger
Use when changing WidgetSnapshotService, SharedSnapshot, PurgeQuestWidget, App Group suite name, timeline providers, Lock Screen accessories, or any code that writes state the widget must display.

## Inputs
- App Group identifier (e.g. group.com.purgequest.app)
- SharedSnapshot (or equivalent Codable struct) duplicated in app and widget targets
- WidgetSnapshotService write path and widget TimelineProvider read path
- Entitlements on both the main app and the widget extension

## Process
1. Never import the main app module into the widget target. Duplicate only the minimal Codable snapshot type.
2. Write the snapshot from the main app only after meaningful state changes (quest refresh, streak update, combat end, settings change).
3. Keep the snapshot small — IDs, counts, short strings, dates, booleans. Never embed images, full media lists, or large JSON blobs.
4. Use a single suiteName UserDefaults (or a single file URL in the shared container) as the source of truth for the widget.
5. Call WidgetCenter.shared.reloadAllTimelines() (or specific kind) after every successful write.
6. On the widget side, treat missing or undecodable snapshot as empty state, not a crash.
7. Version the snapshot struct (or add a schemaVersion field) so future fields can be added without breaking old widgets.
8. Confirm both targets have the identical App Group entitlement enabled under the same team.

## Tools
- WidgetKit + WidgetCenter
- App Group UserDefaults or shared container FileManager
- Codable for the snapshot
- Xcode Signing and Capabilities for App Group provisioning

## Output
- Updated SharedSnapshot and write/read paths that stay in sync
- Explicit reload call after writes
- Graceful empty state in the widget when data is missing
- Note of any entitlement or team steps required

## Quality checks
- A timeline reload is requested after a write, and the widget eventually displays current data in device testing; WidgetKit controls actual scheduling
- Snapshot size stays bounded
- No force-unwraps on missing data
- App Group is present on both targets

## Failure handling
- Decode failure yields a default empty snapshot and a debug log
- If the App Group is not provisioned, document the exact capability steps rather than failing silently
- Stale timelines are fixed by an explicit reload, not by polling

## Metrics
- Write then reload eventually produces a visible update on Home Screen or Lock Screen, subject to WidgetKit scheduling
- Snapshot remains Codable and version-tolerant
- Agent can state the exact suite name and the fields currently shared
