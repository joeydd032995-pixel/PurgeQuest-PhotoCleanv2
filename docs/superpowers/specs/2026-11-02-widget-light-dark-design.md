# Home-Screen Widgets: Light and Dark with the Classic Palette — Design

Follows the app-wide Light/Dark work (PR #14). This document covers only the home-screen widgets; the Lock Screen widgets and the Live Activity are explained under "Scope".

## Goal

The Daily Quest (small, medium) and Streak (small) widgets follow the system's Light/Dark appearance and wear the app's Classic palette (charcoal in Dark, parchment in Light), so they are legible in both modes and match the app's default look.

## Verified starting state (repository, 2026-11-02)

- The widget target `PurgeQuestWidget` is a synchronized folder, `ios/PurgeQuestWidget/`, holding `PurgeQuestWidget.swift`, `PurgeQuestWidgetBundle.swift` and `SharedSnapshot.swift`. It is self-contained on purpose: `SharedSnapshot.swift` mirrors the app's snapshot struct instead of importing app code. A new Swift file placed in that folder compiles into the extension with no project-file edit.
- Four widgets are declared: `DailyQuestWidget` (systemSmall, systemMedium), `StreakWidget` (systemSmall), `LockScreenGemWidget` (accessoryCircular) and `LockScreenStreakWidget` (accessoryRectangular). The two Lock Screen widgets use `AccessoryWidgetBackground`, `.widgetAccentable()` and a clear container, so the system tints them and they carry no custom colors.
- The two home-screen widgets hard-code the old green-black ("Verdigris Deep") Dark look:
  - container gradients from `Color(red: 0.031, green: 0.059, blue: 0.047)` and `Color(red: 0.078, green: 0.129, blue: 0.110)`, which are the Verdigris `canvasTop` and `surface` in Dark;
  - accent literals that equal the app's shared Dark accents: amber `(0.890, 0.702, 0.255)`, sapphire `(0.427, 0.608, 0.710)`, crimson `(0.769, 0.357, 0.306)`, emerald `(0.239, 0.620, 0.463)`;
  - a progress track of `.white.opacity(0.12)` and a hero level numeral of `.white`;
  - text in the system `.primary` and `.secondary` styles on that fixed dark background, so in system Light mode the text is near-black on near-black.
- There is no Live Activity UI. `CombatLiveActivityService.swift` says the rendering UI "lives in a Widget Extension target (added in a future build pass)", and `ActivityConfiguration` and `DynamicIsland` appear nowhere in the repository.
- The app's palette is `ThemePalette` (Foundation-only; Classic and Verdigris) with its contrast rules covered by `ThemePaletteTests`. The in-app Mode and Palette settings live in the app's own `UserDefaults.standard`, not in the shared App Group, so a widget cannot read them.

## Decisions (with the user, 2026-11-02)

1. The widgets follow Light/Dark only and keep one palette; they do not follow the in-app Palette picker.
2. That palette is **Classic**, the app's default, not Verdigris.
3. **Approach A**: a widget-only palette file plus a drift guard. The alternatives were rejected: sharing `ThemePalette.swift` with the widget target needs hand edits to `project.pbxproj` without Xcode and ends the widget's self-contained design; an asset catalog adds about nine colour sets, still duplicates the values, and is harder to guard.
4. They follow the **system** appearance. Following the in-app Mode picker would need the app to publish it through the App Group and the widget to override its color scheme, which is extra plumbing for little gain.

## Scope

In: the views of `DailyQuestWidget` and `StreakWidget`; two new files in the widget folder; one new `repo_guard.py` check; this document.

Out: the Lock Screen widgets (system-tinted); any Live Activity (no UI exists, and building one is a separate feature); mirroring the in-app Mode or Palette; the iOS 18 Tinted and accented rendering modes (unchanged); layout and typography; the snapshot schema and the App Group key.

## Design

### Tokens

`ios/PurgeQuestWidget/WidgetPalette.swift` is Foundation-only and holds the nine colors the home-screen widgets use, each as a Light and Dark pair of `0xRRGGBB` values, named after the app token they copy:

| Token | Light | Dark | App source |
|---|---|---|---|
| `canvasTop` | `0xF9F9F2` | `0x141413` | `ThemePalette.classic.canvasTop` |
| `surface` | `0xFBFAF4` | `0x2A2927` | `ThemePalette.classic.surface` |
| `hairline` | `0xD9D4C0` | `0x45433F` | `ThemePalette.classic.hairline` |
| `textPrimary` | `0x1B1B17` | `0xF2EFE9` | `ThemePalette.classic.textPrimary` |
| `textSecondary` | `0x5A574A` | `0xB0ACA3` | `ThemePalette.classic.textSecondary` |
| `amber` | `0x8A6210` | `0xE3B341` | `ThemePalette.amber` |
| `sapphire` | `0x2D6A8E` | `0x6D9BB5` | `ThemePalette.sapphire` |
| `crimson` | `0xA93B2E` | `0xC45B4E` | `ThemePalette.crimson` |
| `emerald` | `0x1F7452` | `0x3D9E76` | `ThemePalette.emerald` |

The app writes its Dark accents as floats; the widget values are those floats rounded to 8 bits (for example amber `0.890, 0.702, 0.255` is `0xE3B341`).

`ios/PurgeQuestWidget/WidgetColors.swift` turns each pair into a SwiftUI `Color` with a dynamic `UIColor` provider that picks the Light or Dark value from the trait collection, the same technique the app's `Color+Theme.swift` uses.

### Views

`PurgeQuestWidget.swift` replaces its fixed colors; layout, fonts and the snapshot are untouched.

| Role | Token |
|---|---|
| Daily Quest container gradient (small and medium), top to bottom | `canvasTop` to `surface` |
| Streak container gradient, top to bottom | `surface` to `canvasTop` |
| Quest accent (label, count, progress fill, crest tint) | `sapphire` for a video quest, `amber` otherwise |
| Streak label and flame in the Streak widget; flame and count in the medium Daily Quest widget | `crimson` |
| Gem diamond | `emerald` |
| Titles, numbers, hero level numeral | `textPrimary` |
| Subtitle, "LV", "d", "freed" | `textSecondary` |
| Progress track | `hairline` |

The Lock Screen views are not edited.

### Drift guard

`tools/ci/repo_guard.py` gains a check, "Widget palette", that runs on Linux in seconds:

1. Parse `WidgetPalette.swift` and the matching tokens from `ThemePalette.swift` (Classic neutrals and the shared accents), reading both the `hex:` and the `red:green:blue:` forms, and fail if any Light or Dark value differs when compared as 8-bit sRGB.
2. Check contrast of each text and accent token on both widget backgrounds (`canvasTop` and `surface`) in each appearance, using the thresholds in `ThemePaletteTests`: primary text 7, secondary text 4.5, Light accents 4.5, Dark accents 3.
3. Fail if `PurgeQuestWidget.swift` contains a raw `Color(red:` literal, `.white`, or a black color (`Color.black`, or `.black` passed to `foregroundStyle`, `fill`, `stroke`, `tint` or `background`), so a fixed color cannot creep back in. (`.primary` is allowed: the Lock Screen views use it for system tinting. The `.black` font weight is allowed too.)

Contrast computed from the proposed values (lowest of the two backgrounds):

| Token | Light | Dark |
|---|---|---|
| `textPrimary` (floor 7) | 16.34 | 12.66 |
| `textSecondary` (floor 4.5) | 6.86 | 6.42 |
| `amber` (floors 4.5 / 3) | 5.18 | 7.47 |
| `sapphire` | 5.57 | 4.85 |
| `crimson` | 5.92 | 3.43 |
| `emerald` | 5.40 | 4.40 |

### Data flow and errors

Unchanged. The app still writes the snapshot to the App Group and the widget reads it. Colors are static, so there is no new failure path.

## Verification

- `repo_guard.py` (parity, contrast, no raw literals) runs in the Repo guard workflow.
- The iOS Build and Analyze workflow builds the app scheme, which embeds and compiles the extension, so a compile error in the widget fails CI.
- The look was approved from a mock drawn from these values (not a WidgetKit render).
- **Not verifiable in CI:** a real widget render. After merge the user confirms on a device:
  1. Add Daily Quest (small and medium) and Streak (small) to the Home Screen.
  2. With the system in Light, then in Dark, text is readable; the background is parchment in Light and charcoal in Dark.
  3. A video quest uses the blue accent and a photo quest the gold one; the streak flame is red and the gem green.
  4. The Lock Screen widgets look as before.

## Risks

- The values exist in two places (app and widget). The guard fails CI on any difference.
- On an iOS 18 Tinted Home Screen the system recolors widgets; this work neither fixes nor worsens that.
- The Dark crimson floor (3.43 against 3) is the tightest margin; it matches the app, which uses the same pair.

## Acceptance criteria

1. In system Light and Dark, every text and accent color on the Daily Quest and Streak widgets meets the thresholds above (guard-enforced).
2. No raw `Color(red:` literal, `.white` or black color remains in `PurgeQuestWidget.swift`.
3. The Lock Screen widgets, the snapshot struct and the App Group key are unchanged.
4. `repo_guard.py` fails if a widget token differs from the app's Classic palette.
5. CI is green, including the extension compile.
