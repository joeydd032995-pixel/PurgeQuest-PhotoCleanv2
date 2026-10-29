# Allowed First-Party Surface (default)

Prefer first-party frameworks that fit the task, including:

- SwiftUI, SwiftData, Observation
- Photos / PhotosUI
- AVFoundation (video previews)
- CoreImage, Vision (on-device analysis)
- CoreHaptics
- WidgetKit, ActivityKit (conditional)
- StoreKit 2
- FoundationModels (Apple Intelligence, gated)
- UserDefaults (App Group suites)
- ImageRenderer / ShareLink for shareable cards

Avoid by default:
- Any third-party package manager dependency
- Network clients for analytics or remote config
- Permanent file deletion APIs
