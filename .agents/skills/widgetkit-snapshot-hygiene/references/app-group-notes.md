# App Group + Widget Snapshot Notes

- Suite name must match the entitlement on both targets exactly.
- Widget extension cannot see main-app types; copy only the Codable snapshot.
- Prefer UserDefaults(suiteName:) for small state; use the shared container only if you need files.
- Always reload timelines after a write. Widgets do not observe UserDefaults automatically in all cases.
- Lock Screen accessory widgets still consume the same snapshot; keep fields generic enough for both.
