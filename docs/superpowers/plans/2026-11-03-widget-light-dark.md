# Home-Screen Widgets: Light/Dark with the Classic Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Daily Quest (small, medium) and Streak (small) widgets follow the system's Light/Dark appearance in the app's Classic palette, and CI fails if their colors drift from the app's.

**Architecture:** A Foundation-only `WidgetPalette.swift` holds nine Light/Dark hex pairs copied from the app's Classic palette. `WidgetColors.swift` turns them into dynamic SwiftUI colors. `PurgeQuestWidget.swift` uses those instead of fixed literals and system `.primary`/`.secondary`. A new check in `tools/ci/repo_guard.py` fails CI if a widget color differs from the app's, loses contrast, or a raw color literal returns to the views.

**Tech Stack:** Swift 5 mode, SwiftUI and WidgetKit (widget extension), Python 3 standard library only (`repo_guard.py`).

Spec: `docs/superpowers/specs/2026-11-02-widget-light-dark-design.md` (merged in PR #17). Where this plan refines the spec (the black-color rule in Task 2), Task 2 also updates the spec.

## Global Constraints

- Work on branch `claude/widget-light-dark-impl`, created from `main` at `4c64dc3`. PR #17 is merged, so this is a new PR. Never merge it.
- The palette is **Classic**. The widgets follow the **system** Light/Dark and ignore the in-app Mode and Palette settings.
- Exactly nine tokens, values verbatim (`0xRRGGBB`, Light / Dark):

  | Token | Light | Dark |
  |---|---|---|
  | `canvasTop` | `0xF9F9F2` | `0x141413` |
  | `surface` | `0xFBFAF4` | `0x2A2927` |
  | `hairline` | `0xD9D4C0` | `0x45433F` |
  | `textPrimary` | `0x1B1B17` | `0xF2EFE9` |
  | `textSecondary` | `0x5A574A` | `0xB0ACA3` |
  | `amber` | `0x8A6210` | `0xE3B341` |
  | `sapphire` | `0x2D6A8E` | `0x6D9BB5` |
  | `crimson` | `0xA93B2E` | `0xC45B4E` |
  | `emerald` | `0x1F7452` | `0x3D9E76` |

- Contrast floors, measured on both widget backgrounds (`canvasTop` and `surface`): primary text 7, secondary text 4.5, Light accents 4.5, Dark accents 3.
- Unchanged: the Lock Screen widgets (`LockScreenGemWidget`, `LockScreenStreakWidget`, `LockGemView`, `LockRectView`), `PurgeQuestWidgetSnapshot`, `WidgetSnapshotReader`, the App Group `group.com.purgequest.app` and key `purgequest.widget.snapshot.v1`, layout and typography.
- Widget target settings: `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `IPHONEOS_DEPLOYMENT_TARGET = 18.0`. Pure-data types are marked `nonisolated`, as `PurgeEntry` already is.
- No third-party packages and no networking (`repo_guard.py` enforces both).
- There is no Xcode in the sandbox: the Python guard runs locally; Swift compiles only in CI.
- Every commit message ends with these two lines:
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01Rd6J3u4BgjJrKPVVCUDZz5`
  The PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`, a blank line, and the session URL.

---

### Task 1: The widget palette and the guard that keeps it in step

**Files:**
- Modify: `tools/ci/repo_guard.py` (docstring list at the top; new check 8 before `if failures:`; final `print`)
- Create: `ios/PurgeQuestWidget/WidgetPalette.swift`

**Interfaces:**
- Produces: `struct WidgetPair { let light: UInt32; let dark: UInt32 }` and `enum WidgetPalette` with nine `static let` members of type `WidgetPair`: `canvasTop`, `surface`, `hairline`, `textPrimary`, `textSecondary`, `amber`, `sapphire`, `crimson`, `emerald`. Task 2 builds colors from them.

- [ ] **Step 1: Write the failing check**

In `tools/ci/repo_guard.py`, add to the docstring list after item 7:

```
  8. Widget palette: the home-screen widgets' colors match the app's Classic palette, stay readable
     on the widget backgrounds, and the widget views use no fixed colors.
```

Insert this block immediately before the `if failures:` line:

```python
# 8. widget palette
# The widget target is self-contained, so its colors are a copy of the app's Classic palette. Keep the
# copy honest: same values, readable on the widget backgrounds, and (below) no fixed colors in the views.
WIDGET_DIR = IOS / "PurgeQuestWidget"
WIDGET_TOKENS = (
    "canvasTop", "surface", "hairline", "textPrimary", "textSecondary",
    "amber", "sapphire", "crimson", "emerald",
)
WIDGET_FLOORS = {  # (Light, Dark) minimum contrast, as in ThemePaletteTests
    "textPrimary": (7, 7), "textSecondary": (4.5, 4.5),
    "amber": (4.5, 3), "sapphire": (4.5, 3), "crimson": (4.5, 3), "emerald": (4.5, 3),
}
APP_PAIR = (
    r"ThemePair\(light:\s*0x([0-9A-Fa-f]{6}),\s*dark:\s*ThemeRGB\("
    r"(?:hex:\s*0x([0-9A-Fa-f]{6})|red:\s*([0-9.]+),\s*green:\s*([0-9.]+),\s*blue:\s*([0-9.]+))\)\)"
)


def eight_bit(value):
    return int(float(value) * 255 + 0.5)


def app_pair(light, dark_hex, red, green, blue):
    dark = int(dark_hex, 16) if dark_hex else (eight_bit(red) << 16) | (eight_bit(green) << 8) | eight_bit(blue)
    return int(light, 16), dark


def luminance(rgb):
    def channel(value):
        value /= 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return 0.2126 * channel((rgb >> 16) & 255) + 0.7152 * channel((rgb >> 8) & 255) + 0.0722 * channel(rgb & 255)


def contrast_ratio(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


theme_src = (IOS / "PurgeQuest/Models/ThemePalette.swift").read_text()
classic_src = theme_src.split("static let classic = ThemeNeutrals(", 1)[1].split("static let verdigris", 1)[0]
app_tokens = {m.group(1): app_pair(*m.groups()[1:]) for m in re.finditer(r"(\w+):\s*" + APP_PAIR, classic_src)}
for m in re.finditer(r"static let (\w+)\s*=\s*" + APP_PAIR, theme_src):
    app_tokens.setdefault(m.group(1), app_pair(*m.groups()[1:]))

palette_file = WIDGET_DIR / "WidgetPalette.swift"
if not palette_file.exists():
    failures.append("widget palette: ios/PurgeQuestWidget/WidgetPalette.swift is missing")
    widget_tokens = {}
else:
    widget_tokens = {
        m.group(1): (int(m.group(2), 16), int(m.group(3), 16))
        for m in re.finditer(
            r"static let (\w+)\s*=\s*WidgetPair\(light:\s*0x([0-9A-Fa-f]{6}),\s*dark:\s*0x([0-9A-Fa-f]{6})\)",
            strip_comments(palette_file.read_text()),
        )
    }
    for token in WIDGET_TOKENS:
        if token not in widget_tokens:
            failures.append(f"widget palette: WidgetPalette.{token} is missing")
        elif token not in app_tokens:
            failures.append(f"widget palette: no Classic '{token}' in ThemePalette.swift to compare with (parser out of date?)")
        elif widget_tokens[token] != app_tokens[token]:
            failures.append(
                "widget palette: %s is light %06X / dark %06X but the app's Classic palette has light %06X / dark %06X"
                % (token, *widget_tokens[token], *app_tokens[token])
            )
    for token in sorted(set(widget_tokens) - set(WIDGET_TOKENS)):
        failures.append(f"widget palette: WidgetPalette.{token} is not in WIDGET_TOKENS, so nothing guards it")
    for token, floors in WIDGET_FLOORS.items():
        for index, appearance in enumerate(("Light", "Dark")):
            for background in ("canvasTop", "surface"):
                if token in widget_tokens and background in widget_tokens:
                    got = contrast_ratio(widget_tokens[token][index], widget_tokens[background][index])
                    if got < floors[index]:
                        failures.append(
                            f"widget palette: {token} on {background} in {appearance} is {got:.2f}:1, below {floors[index]}:1"
                        )
```

Change the final `print` to include the token count:

```python
print(f"repo_guard ok ({len(used)} seasonal IDs, {len(catalog_ids)} catalog items, {len(family_cases)} family icons, {len(widget_tokens)} widget tokens)")
```

- [ ] **Step 2: Run the guard to verify it fails**

Run: `python3 -I tools/ci/repo_guard.py`
Expected: exit code 1 and

```
repo_guard FAILED:
  - widget palette: ios/PurgeQuestWidget/WidgetPalette.swift is missing
```

- [ ] **Step 3: Create the palette**

Create `ios/PurgeQuestWidget/WidgetPalette.swift`:

```swift
//
//  WidgetPalette.swift
//  PurgeQuestWidget
//
//  The nine colors the home-screen widgets use, as Light and Dark 0xRRGGBB pairs. They copy the
//  app's Classic palette (ThemePalette.swift). The widget target stays self-contained, so
//  tools/ci/repo_guard.py fails CI if any value drifts from the app's, or loses contrast on the
//  widget backgrounds (canvasTop and surface).
//

import Foundation

/// One color in both appearances.
nonisolated struct WidgetPair: Equatable, Sendable {
    let light: UInt32
    let dark: UInt32
}

nonisolated enum WidgetPalette {
    // Neutrals: ThemePalette.classic
    static let canvasTop     = WidgetPair(light: 0xF9F9F2, dark: 0x141413)
    static let surface       = WidgetPair(light: 0xFBFAF4, dark: 0x2A2927)
    static let hairline      = WidgetPair(light: 0xD9D4C0, dark: 0x45433F)
    static let textPrimary   = WidgetPair(light: 0x1B1B17, dark: 0xF2EFE9)
    static let textSecondary = WidgetPair(light: 0x5A574A, dark: 0xB0ACA3)

    // Accents shared by both app palettes: ThemePalette.amber, .sapphire, .crimson, .emerald
    static let amber    = WidgetPair(light: 0x8A6210, dark: 0xE3B341)
    static let sapphire = WidgetPair(light: 0x2D6A8E, dark: 0x6D9BB5)
    static let crimson  = WidgetPair(light: 0xA93B2E, dark: 0xC45B4E)
    static let emerald  = WidgetPair(light: 0x1F7452, dark: 0x3D9E76)
}
```

- [ ] **Step 4: Run the guard to verify it passes**

Run: `python3 -I tools/ci/repo_guard.py`
Expected: exit code 0 and `repo_guard ok (7 seasonal IDs, 35 catalog items, 6 family icons, 9 widget tokens)`

- [ ] **Step 5: Prove the guard bites**

Stage the file so a restore is one command, mutate it, check the failure, restore:

```bash
git add ios/PurgeQuestWidget/WidgetPalette.swift
sed -i 's/dark: 0xE3B341/dark: 0xE3B342/' ios/PurgeQuestWidget/WidgetPalette.swift
python3 -I tools/ci/repo_guard.py; echo "exit=$?"
git checkout -- ios/PurgeQuestWidget/WidgetPalette.swift
sed -i 's/light: 0x5A574A/light: 0xB5B2A5/' ios/PurgeQuestWidget/WidgetPalette.swift
python3 -I tools/ci/repo_guard.py; echo "exit=$?"
git checkout -- ios/PurgeQuestWidget/WidgetPalette.swift
python3 -I tools/ci/repo_guard.py; echo "exit=$?"
```

Expected, in order:
1. `exit=1` with `widget palette: amber is light 8A6210 / dark E3B342 but the app's Classic palette has light 8A6210 / dark E3B341`
2. `exit=1` with the `textSecondary` parity line and two lines `widget palette: textSecondary on canvasTop in Light is 2.01:1, below 4.5:1` and `... on surface in Light is 2.03:1, below 4.5:1`
3. `exit=0` and the `repo_guard ok (...)` line again.

- [ ] **Step 6: Commit**

```bash
git add tools/ci/repo_guard.py ios/PurgeQuestWidget/WidgetPalette.swift
git commit -m "Add the widget palette and a guard that keeps it in step with the app

WidgetPalette.swift holds the nine colors the home-screen widgets will use,
copied from the app's Classic palette. A new repo_guard.py check fails if any
value differs from ThemePalette.swift, or if a text or accent color falls below
the app's contrast floors on the widget backgrounds.

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Rd6J3u4BgjJrKPVVCUDZz5"
```

---

### Task 2: Adaptive colors and the widget views

**Files:**
- Modify: `tools/ci/repo_guard.py` (add the fixed-color check after the palette check)
- Create: `ios/PurgeQuestWidget/WidgetColors.swift`
- Modify: `ios/PurgeQuestWidget/PurgeQuestWidget.swift` (`DailyQuestWidgetView`, `StreakWidgetView`, `ProgressBar`; everything else untouched)
- Modify: `docs/superpowers/specs/2026-11-02-widget-light-dark-design.md` (guard rule 3 and acceptance criterion 2)

**Interfaces:**
- Consumes: `WidgetPair` and `WidgetPalette.<token>` from Task 1.
- Produces: `Color.init(_ pair: WidgetPair)` and nine statics: `Color.widgetCanvasTop`, `.widgetSurface`, `.widgetHairline`, `.widgetTextPrimary`, `.widgetTextSecondary`, `.widgetAmber`, `.widgetSapphire`, `.widgetCrimson`, `.widgetEmerald`.

- [ ] **Step 1: Write the failing check**

In `tools/ci/repo_guard.py`, add directly after the palette check (before `if failures:`). Note the `.black` font weight (`.weight(.black)`) is legitimate, so only black *colors* are banned:

```python
widget_views = strip_comments((WIDGET_DIR / "PurgeQuestWidget.swift").read_text())
for pattern, what in (
    (r"\bColor\(red:", "a raw Color(red:) literal"),
    (r"\.white\b", ".white"),
    (r"\bColor\.black\b|(?:foregroundStyle|fill|stroke|tint|background)\(\s*\.black\b", "a black color"),
):
    if re.search(pattern, widget_views):
        failures.append(f"widget palette: PurgeQuestWidget.swift uses {what}; use the Color.widget* tokens")
```

- [ ] **Step 2: Run the guard to verify it fails**

Run: `python3 -I tools/ci/repo_guard.py`
Expected: exit code 1 and exactly these two lines (the `.black` font weights must not be flagged):

```
repo_guard FAILED:
  - widget palette: PurgeQuestWidget.swift uses a raw Color(red:) literal; use the Color.widget* tokens
  - widget palette: PurgeQuestWidget.swift uses .white; use the Color.widget* tokens
```

- [ ] **Step 3: Create the adaptive colors**

Create `ios/PurgeQuestWidget/WidgetColors.swift`:

```swift
//
//  WidgetColors.swift
//  PurgeQuestWidget
//
//  SwiftUI colors for the widget palette. Each one is dynamic: it resolves to the Light or Dark
//  value of the appearance it is drawn in, which for a widget is the system's.
//

import SwiftUI
import UIKit

extension Color {
    /// Resolves to `pair.light` or `pair.dark` with the appearance it is drawn in.
    init(_ pair: WidgetPair) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? pair.dark : pair.light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let widgetCanvasTop = Color(WidgetPalette.canvasTop)
    static let widgetSurface = Color(WidgetPalette.surface)
    static let widgetHairline = Color(WidgetPalette.hairline)
    static let widgetTextPrimary = Color(WidgetPalette.textPrimary)
    static let widgetTextSecondary = Color(WidgetPalette.textSecondary)
    static let widgetAmber = Color(WidgetPalette.amber)
    static let widgetSapphire = Color(WidgetPalette.sapphire)
    static let widgetCrimson = Color(WidgetPalette.crimson)
    static let widgetEmerald = Color(WidgetPalette.emerald)
}
```

- [ ] **Step 4: Replace the Daily Quest view**

In `ios/PurgeQuestWidget/PurgeQuestWidget.swift`, replace everything from the line `struct DailyQuestWidgetView: View {` up to, but not including, the line `struct DailyQuestWidget: Widget {` with:

```swift
struct DailyQuestWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PurgeEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var progress: Double {
        guard entry.snapshot.questTarget > 0 else { return 0 }
        return min(1.0, Double(entry.snapshot.questCurrent) / Double(entry.snapshot.questTarget))
    }

    private var accent: Color {
        entry.snapshot.questIsVideo ? Color.widgetSapphire : Color.widgetAmber
    }

    /// The canvas gradient both sizes share.
    private var background: some View {
        LinearGradient(
            colors: [Color.widgetCanvasTop, Color.widgetSurface],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: entry.snapshot.questIsVideo ? "film.fill" : "scroll.fill")
                    .font(.caption.weight(.bold))
                Text("DAILY QUEST")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundStyle(accent)

            Text(entry.snapshot.questTitle)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .lineLimit(2)
                .foregroundStyle(Color.widgetTextPrimary)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.snapshot.questCurrent) / \(entry.snapshot.questTarget)")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(accent)
                ProgressBar(progress: progress, tint: accent)
                    .frame(height: 6)
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: entry.snapshot.questIsVideo ? "film.fill" : "scroll.fill")
                    Text("DAILY QUEST")
                        .tracking(0.6)
                }
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)

                Text(entry.snapshot.questTitle)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.widgetTextPrimary)
                    .lineLimit(1)

                Text(entry.snapshot.questSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.widgetTextSecondary)
                    .lineLimit(2)

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(entry.snapshot.questCurrent) / \(entry.snapshot.questTarget)")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(accent)
                        Spacer()
                        Label("\(entry.snapshot.streakDays)", systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.widgetCrimson)
                    }
                    ProgressBar(progress: progress, tint: accent)
                        .frame(height: 7)
                }
            }
            // Hero crest
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .overlay(Circle().stroke(accent.opacity(0.6), lineWidth: 1.5))
                    Text("\(entry.snapshot.heroLevel)")
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(Color.widgetTextPrimary)
                }
                .frame(width: 56, height: 56)
                Text("LV")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.widgetTextSecondary)
            }
        }
        .containerBackground(for: .widget) { background }
    }
}

```

- [ ] **Step 5: Replace the Streak view and the progress track**

In the same file, replace everything from the line `struct StreakWidgetView: View {` up to, but not including, the line `struct StreakWidget: Widget {` with:

```swift
struct StreakWidgetView: View {
    let entry: PurgeEntry

    private var freedString: String {
        let mb = entry.snapshot.totalMBFreed
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return "\(Int(mb.rounded())) MB"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STREAK")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Color.widgetCrimson)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.widgetCrimson)
                Text("\(entry.snapshot.streakDays)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Color.widgetTextPrimary)
                Text("d")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.widgetTextSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "internaldrive.fill")
                    .font(.caption2)
                Text(freedString + " freed")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.widgetTextSecondary)

            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.widgetEmerald)
                Text("\(entry.snapshot.gems)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.widgetTextPrimary)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.widgetSurface, Color.widgetCanvasTop],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

```

Then replace the one line `RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.12))` in `ProgressBar` with:

```swift
                RoundedRectangle(cornerRadius: 2).fill(Color.widgetHairline)
```

- [ ] **Step 6: Run the guard to verify it passes**

Run: `python3 -I tools/ci/repo_guard.py`
Expected: exit code 0 and `repo_guard ok (7 seasonal IDs, 35 catalog items, 6 family icons, 9 widget tokens)`

Also confirm nothing outside the two views and the track changed:

Run: `git diff --stat -- ios/PurgeQuestWidget/PurgeQuestWidget.swift`
Expected: only that file, with the Lock Screen views, provider and `DailyQuestWidget`/`StreakWidget` declarations untouched. Check with: `git diff -- ios/PurgeQuestWidget/PurgeQuestWidget.swift | grep -c "LockGemView\|LockRectView\|PurgeProvider"` which must print `0`.

- [ ] **Step 7: Update the spec to match the refined rule**

In `docs/superpowers/specs/2026-11-02-widget-light-dark-design.md`, replace guard rule 3:

```
3. Fail if `PurgeQuestWidget.swift` contains a raw `Color(red:` literal, `.white` or `.black`, so a fixed color cannot creep back in. (`.primary` is allowed: the Lock Screen views use it for system tinting.)
```

with:

```
3. Fail if `PurgeQuestWidget.swift` contains a raw `Color(red:` literal, `.white`, or a black color (`Color.black`, or `.black` passed to `foregroundStyle`, `fill`, `stroke`, `tint` or `background`), so a fixed color cannot creep back in. (`.primary` is allowed: the Lock Screen views use it for system tinting. The `.black` font weight is allowed too.)
```

and acceptance criterion 2:

```
2. No raw `Color(red:` literal, `.white` or `.black` remains in `PurgeQuestWidget.swift`.
```

with:

```
2. No raw `Color(red:` literal, `.white` or black color remains in `PurgeQuestWidget.swift`.
```

- [ ] **Step 8: Commit**

```bash
git add tools/ci/repo_guard.py ios/PurgeQuestWidget/WidgetColors.swift ios/PurgeQuestWidget/PurgeQuestWidget.swift docs/superpowers/specs/2026-11-02-widget-light-dark-design.md
git commit -m "Make the home-screen widgets follow Light/Dark with the Classic palette

The Daily Quest and Streak widgets drew a fixed green-black gradient but used
system primary and secondary text, which is near-black on near-black in system
Light mode. They now use dynamic Classic colors from WidgetPalette, and the
guard fails if a raw color literal returns to the views. The spec's rule for
black is narrowed to colors, since the black font weight is legitimate.

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Rd6J3u4BgjJrKPVVCUDZz5"
```

---

### Task 3: Ship it: PR, CI, and the visuals you asked for

**Files:**
- Create (outside the repo, in the session scratchpad): a mock image generated from the shipped palette file.

**Interfaces:**
- Consumes: the committed `ios/PurgeQuestWidget/WidgetPalette.swift`.

- [ ] **Step 1: Add this plan to the branch and push**

```bash
git add docs/superpowers/plans/2026-11-03-widget-light-dark.md
git commit -m "Add the implementation plan for the Light/Dark widgets

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Rd6J3u4BgjJrKPVVCUDZz5"
git push -u origin claude/widget-light-dark-impl
```

- [ ] **Step 2: Open the PR and subscribe**

Open a ready-for-review PR from `claude/widget-light-dark-impl` into `main` titled `Widgets: follow Light/Dark with the Classic palette`. The body links the spec, summarises the change (two new widget files, the colour swaps, the guard), lists the on-device check from the spec, states what CI can and cannot verify, and ends with the footer in Global Constraints. Then call `subscribe_pr_activity` for the new PR.

- [ ] **Step 3: Read the real check runs**

Use `pull_request_read get_check_runs` on the PR. Do not trust a "check suite completed" notice. Expected on the final head: `guard` (runs the new check), `build-and-analyze` (compiles the app and the embedded widget extension), `assets`, `swift-pure-logic` and `unit-tests` all `success`. A failure in `build-and-analyze` is a Swift compile error in the widget files: read the job log, fix it in a new commit, push, and read the check runs again. A red `unit-tests` run whose failing step is "Run Forge UI tests" with launch timeouts is the intermittent failure already documented in PR #15: re-run the failed job once and report both results.

- [ ] **Step 4: Render the mock from the shipped constants**

The approved mock hard-coded its colors. Regenerate it reading the real file, so the image can be traced to the code. In the scratchpad copy of `widget_mock.py`, replace the hard-coded `T = {...}` dictionary with:

```python
import re
src = open(sys.argv[2]).read()
T = {name: (int(light, 16), int(dark, 16)) for name, light, dark in re.findall(
    r"static let (\w+)\s*=\s*WidgetPair\(light:\s*0x([0-9A-Fa-f]{6}),\s*dark:\s*0x([0-9A-Fa-f]{6})\)", src)}
T["text"], T["text2"] = T["textPrimary"], T["textSecondary"]
```

Run: `python3 -I <scratchpad>/tools/widget_mock.py <scratchpad>/widget-mock-shipped.png ios/PurgeQuestWidget/WidgetPalette.swift`
Expected: `wrote ... (1628, 1048)`. View the image, confirm it matches the approved mock, and send it with `SendUserFile`, captioned as drawn from the shipped palette file and not a WidgetKit render.

- [ ] **Step 5: Report**

Update the PR body with the verification table (guard output, CI results with run links) and keep the on-device checklist. Tell the user, leading with the outcome: what changed, what CI proved, what it cannot prove (a real render; the iOS 18 Tinted mode), and that merging is theirs.
