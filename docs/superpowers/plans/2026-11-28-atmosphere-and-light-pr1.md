# Atmosphere and light, PR 1: one torch (implementation plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the canvas's torch becomes a gold light you can see, at the top left of every screen, and every lit surface (panels, the gold plate, the Undo pill, the combat HUD and the Delete and Keep buttons) takes the same light direction.

**Architecture:** the numbers live in the Foundation-only `LightSource` (`Models/CardFX.swift`, already in the Linux harness): the torch's position, reach, colour and strength, and the rim's alphas. Views only draw them: `DungeonBackgroundView` draws the torch, three shared surfaces offset their shadows and sheen along the light, and a new `.litEdge(cornerRadius:)` modifier gives the flat HUD tiles and buttons the rim `ExhibitFrame` already uses for the card.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode, SwiftUI, iOS 18 deployment target, Swift Testing, the repo's Linux harness (`tools/swift_harness/run.sh`). No new dependencies, assets, Metal or motion.

**Source:** `docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md`, Part 1 (sections 4, 6 and 7). Part 2 (depth and environments) is **not** in this plan: it is not approved yet, and `intensity` stays unused.

## Global Constraints

- Deployment target iOS 18.0; no third-party SDKs, no network (`tools/ci/repo_guard.py` enforces it); no new image or audio assets.
- Pure models are `import Foundation` only and `nonisolated`; they are already listed in both lists of `tools/swift_harness/run.sh` (`Models/CardFX`, `Models/ThemePalette`, `CardFXTests`), so **no harness change**. Tests use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`).
- **No new hues** (rule 9): the torch uses `ThemePalette.Gold.plateStops[2]` (Dark) and `ThemePalette.Gold.bevel` (Light), both existing tokens.
- **No motion** in this PR (rule 8 is untouched). Every added layer keeps `allowsHitTesting(false)`.
- Text contrast at the torch's brightest point is at least 4.5:1 in all four looks (Light and Dark, Classic and Verdigris), pinned by a test.
- The Dark torch is the owner's "Glow": strength 0.08 (decision D10, 28 November 2026). No tint (D9).
- **No existing test, workflow or CI configuration changes** (the owner said "Leave tests", 28 November 2026). Only additions: five tests inside `CardFXTests`, and the README's count.
- Swift compile lesson: type every value on its own `let`. Never mix `Double`, `CGFloat` and literals in one expression.
- No Swift toolchain exists in the authoring container: **CI is the first compile.** The fast signals are `swift-pure-logic` (about 1 minute) and `build-and-analyze` (about 2 minutes); `unit-tests` takes 30 to 35 and the tour 38 to 57.
- Branch `claude/combat-card-experience-txizxr`. Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01Rd6J3vt6GchNd5X7ApAXHG`. Nothing merges without the owner's explicit ask.

## File structure

| File | Change |
|---|---|
| Modify `ios/PurgeQuest/Models/CardFX.swift` | `LightSource`: `torchX`, `torchReach`, `farShadeReach`, `torchAlpha(isDark:)`, `torchColor(isDark:)`, `rimHighlightAlpha`, `rimShadeAlpha` |
| Modify `ios/PurgeQuestTests/CardFXTests.swift` | Five tests under `// MARK: Torch` |
| Modify `ios/PurgeQuest/Views/Components/DungeonBackgroundView.swift` | The torch; in Light, the far-corner shade |
| Modify `ios/PurgeQuest/Views/Components/DungeonSurface.swift` | `DungeonPanelBackground`: corner sheen, shadow along the light |
| Modify `ios/PurgeQuest/Views/Components/GoldButtonStyle.swift` | `GoldPlate`: shadow along the light |
| Modify `ios/PurgeQuest/Views/Components/UndoPill.swift` | Shadow along the light |
| Create `ios/PurgeQuest/Views/Components/LitEdge.swift` | The `.litEdge(cornerRadius:)` modifier |
| Modify `ios/PurgeQuest/Views/Combat/CombatHUD.swift` | `litEdge` on the bar, the exit button, the combo badge |
| Modify `ios/PurgeQuest/Views/Combat/CombatView.swift` | `litEdge` on the Delete and Keep buttons |
| Modify docs | `DESIGN_SYSTEM.md` (Direction, rule 11), `UI_ASSESSMENT.md` (D9, D10), README harness count (468 to 473) |

---

### Task 1: The torch's numbers and their tests

**Files:**
- Modify: `ios/PurgeQuest/Models/CardFX.swift` (header comment and `LightSource`)
- Test: `ios/PurgeQuestTests/CardFXTests.swift`
- Modify: `README.md` (line 262, the harness count)

**Interfaces:**
- Consumes: `ThemePalette.Gold.plateStops: [(color: ThemeRGB, location: Double)]`, `ThemePalette.Gold.bevel: ThemeRGB`, `ThemePalette.neutrals(for:)`, `ThemeRGB.over(_:alpha:)`, `.relativeLuminance`, `.contrast(with:)`, `ThemePair.resolved(isDark:)` (all existing, `Models/ThemePalette.swift`).
- Produces, for Tasks 2 to 4: `LightSource.torchX: Double`, `LightSource.torchReach: Double`, `LightSource.farShadeReach: Double`, `LightSource.torchAlpha(isDark: Bool) -> Double`, `LightSource.torchColor(isDark: Bool) -> ThemeRGB`, `LightSource.rimHighlightAlpha: Double`, `LightSource.rimShadeAlpha: Double`.

- [ ] **Step 1: Cross-check the test arithmetic outside Swift.** The container has no Swift toolchain, so reproduce `ThemeRGB.over`, `relativeLuminance` and `contrast` in Python for both palettes and both appearances before writing the assertions. Expected (already run on 28 November): Dark luminance rises (Classic 0.0070 to 0.0156, Verdigris 0.0042 to 0.0112); Light luminance falls by under 1% (ratios 0.9925 and 0.9957); the lowest text contrast is 5.3:1 and the floor is 4.5:1.

- [ ] **Step 2: Write the tests.** In `CardFXTests.swift`, directly after `theHighlightRunsFromTheLitSideAndSwingsWithTheShift` and before `// MARK: Progress and arming`, add:

```swift
    // MARK: Torch

    @Test func theTorchSitsLeftOfCentreAndItsLightTravelsRight() {
        #expect(LightSource.torchX > 0 && LightSource.torchX < 0.5)
        #expect(LightSource.direction.x > 0, "left of centre, so the light travels right, as the card's does")
        #expect(LightSource.torchReach > 0)
        #expect(LightSource.farShadeReach > 0)
    }

    @Test func darksTorchIsTheGlowTheOwnerChose() {
        #expect(close(LightSource.torchAlpha(isDark: true), 0.08), "Glow, chosen on 28 November 2026")
        #expect(LightSource.torchAlpha(isDark: false) > 0)
    }

    @Test func theTorchLightsTheDarkCanvasAndDoesNotStainTheLightOne() {
        for theme in ColorTheme.allCases {
            let canvas = ThemePalette.neutrals(for: theme).canvasTop
            let darkAlpha = LightSource.torchAlpha(isDark: true)
            let darkLit = LightSource.torchColor(isDark: true).over(canvas.dark, alpha: darkAlpha)
            #expect(darkLit.relativeLuminance > canvas.dark.relativeLuminance, "\(theme) Dark")
            let lightAlpha = LightSource.torchAlpha(isDark: false)
            let lightLit = LightSource.torchColor(isDark: false).over(canvas.light, alpha: lightAlpha)
            let floor = canvas.light.relativeLuminance * 0.98
            #expect(lightLit.relativeLuminance > floor, "\(theme) Light: a warm wash, not the stain the old pool was")
        }
    }

    @Test func textStaysReadableAtTheTorchsBrightestPoint() {
        for theme in ColorTheme.allCases {
            let n = ThemePalette.neutrals(for: theme)
            for isDark in [true, false] {
                let alpha = LightSource.torchAlpha(isDark: isDark)
                let lit = LightSource.torchColor(isDark: isDark).over(n.canvasTop.resolved(isDark: isDark), alpha: alpha)
                for text in [n.textPrimary, n.textSecondary, n.textTertiary] {
                    let ratio = text.resolved(isDark: isDark).contrast(with: lit)
                    #expect(ratio >= 4.5, "\(theme), dark: \(isDark)")
                }
            }
        }
    }

    @Test func theRimIsFaintAndNeverAFrame() {
        #expect(LightSource.rimHighlightAlpha > 0 && LightSource.rimHighlightAlpha <= 0.3)
        #expect(LightSource.rimShadeAlpha > 0 && LightSource.rimShadeAlpha <= 0.3)
    }
```

- [ ] **Step 3: Write the implementation.** In `Models/CardFX.swift`, change the header comment's second sentence block so it also names the torch, then add the members to `LightSource` after `highlightPoints`.

Header (replace lines 5 to 8):

```swift
//  The numbers behind the combat card's depth and commit feel (design:
//  docs/superpowers/specs/2026-11-27-combat-card-depth-design.md, sections 3 and 4), and the torch every screen
//  shares (docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md, section 4). Views render what this
//  decides and decide nothing themselves. Foundation only, so the Linux harness checks it.
```

Members, inside `LightSource`, after `highlightPoints(shiftDegrees:)`:

```swift
    // MARK: The torch every screen shares

    /// Where the torch sits on a screen's top edge, as a share of its width. Left of centre, so light travels right,
    /// as the card's does.
    static let torchX: Double = 0.30

    /// How far the torch's pool reaches, in points. It fades linearly to nothing at this distance.
    static let torchReach: Double = 420

    /// How far the shade at the far corner reaches in Light, in points.
    static let farShadeReach: Double = 520

    /// The torch's strength at its centre. Dark: the "Glow" the owner chose on 28 November 2026, a gold light. Light:
    /// a warm wash that must not darken the cream (the dark-brown pool it replaces lowered it by about 12%).
    static func torchAlpha(isDark: Bool) -> Double {
        isDark ? 0.08 : 0.14
    }

    /// The torch's colour: the brand's mid-plate gold in Dark, the plate's bevel highlight in Light. Both are existing
    /// tokens, so no new hue enters the app.
    static func torchColor(isDark: Bool) -> ThemeRGB {
        isDark ? ThemePalette.Gold.plateStops[2].color : ThemePalette.Gold.bevel
    }

    /// The faint rim a flat tile takes from the torch: white on the side the light comes from, black on the far side.
    static let rimHighlightAlpha: Double = 0.16
    static let rimShadeAlpha: Double = 0.16
```

- [ ] **Step 4: Update the harness count.** In `README.md` line 262 replace `468 tests in 35 suites` with `473 tests in 35 suites` (five new `@Test` functions, no new suite).

- [ ] **Step 5: Verify.** There is no Swift toolchain here, so the signal is CI's `swift-pure-logic` job: `Compile and test the pure-Foundation sources` must pass, and its summary must read 473 tests in 35 suites. Locally, run `git diff --stat` and confirm only the three files above changed.

- [ ] **Step 6: Commit.**

```bash
git add ios/PurgeQuest/Models/CardFX.swift ios/PurgeQuestTests/CardFXTests.swift README.md
git commit -m "LightSource: the torch's position, reach, colour and strength, and the rim's alphas, with tests"
```

---

### Task 2: The canvas torch

**Files:**
- Modify: `ios/PurgeQuest/Views/Components/DungeonBackgroundView.swift`

**Interfaces:**
- Consumes: Task 1's `LightSource.torchX`, `torchReach`, `farShadeReach`, `torchAlpha(isDark:)`, `torchColor(isDark:)`; existing `Color.init(_ rgb: ThemeRGB)`, `LinearGradient.dungeonBackground`, `Color.canvasVignette`.
- Produces: the canvas every screen and `BarScrims` draw, with the torch.

- [ ] **Step 1: Replace the file's contents** (the public interface, `DungeonBackgroundView(intensity:)`, is unchanged, so all 16 call sites stay as they are):

```swift
//
//  DungeonBackgroundView.swift
//  PurgeQuest
//
//  Static tonal canvas: the palette's base (green-black or charcoal in Dark, cream in Light), a faint vignette,
//  and one soft pool of brand gold falling from the top edge, as if from a torch above the screen's top left
//  (`LightSource`: the card's light, the panels' sheen and every shadow agree with it). In Dark the torch is a gold
//  light; in Light it is a warm wash and the side away from it shades a little deeper. It never moves: no particles,
//  no dot grids, no animation anywhere on the canvas.
//
//  The pool used to be drawn in the gold plate's dark-brown ink, so it shifted the Dark top edge by about two levels
//  and darkened the Light one: no light at all (docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md).
//

import SwiftUI

struct DungeonBackgroundView: View {
    var intensity: Double = 0.0   // Kept for call-site compatibility; the canvas is intentionally static.

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Every value is typed on its own line: one expression mixing Double, CGFloat and literals is more than the
        // compiler will type-check in reasonable time.
        let isDark: Bool = colorScheme == .dark
        let torch = Color(LightSource.torchColor(isDark: isDark))
        let torchAlpha: Double = LightSource.torchAlpha(isDark: isDark)
        let torchCenter = UnitPoint(x: CGFloat(LightSource.torchX), y: 0)
        let torchReach = CGFloat(LightSource.torchReach)
        let farShadeReach = CGFloat(LightSource.farShadeReach)
        ZStack {
            LinearGradient.dungeonBackground
                .ignoresSafeArea()

            RadialGradient(
                colors: [torch.opacity(torchAlpha), torch.opacity(0)],
                center: torchCenter,
                startRadius: 0,
                endRadius: torchReach
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [.clear, .canvasVignette],
                center: .center,
                startRadius: 260,
                endRadius: 720
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Light only: the side away from the torch shades a little deeper. Dark keeps the vignette it has.
            if !isDark {
                RadialGradient(
                    colors: [.canvasVignette, .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: farShadeReach
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }
}
```

- [ ] **Step 2: Verify.** CI's `build-and-analyze` must pass (about 2 minutes). The tour then shows the torch on every screen in Light and Dark; the owner judges it there.

- [ ] **Step 3: Commit.**

```bash
git add ios/PurgeQuest/Views/Components/DungeonBackgroundView.swift
git commit -m "Canvas: the torch is a gold light at the top left, and in Light the far corner shades a little deeper"
```

---

### Task 3: Panels, the gold plate and the Undo pill follow the light

**Files:**
- Modify: `ios/PurgeQuest/Views/Components/DungeonSurface.swift` (`DungeonPanelBackground.body`)
- Modify: `ios/PurgeQuest/Views/Components/GoldButtonStyle.swift` (`GoldPlate.body`)
- Modify: `ios/PurgeQuest/Views/Components/UndoPill.swift` (`body`)

**Interfaces:**
- Consumes: existing `LightSource.shadowOffset(depth:) -> (x: Double, y: Double)`.
- Produces: shadows and a sheen that fall and start along the torch's light.

- [ ] **Step 1: `DungeonPanelBackground`.** Replace its `body` with:

```swift
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark: Bool = colorScheme == .dark
        let sheenAlpha: Double = isDark ? 0.045 : 0.35
        let shadowAlpha: Double = elevated ? (isDark ? 0.32 : 0.07) : 0
        let offset = LightSource.shadowOffset(depth: 3)
        let shadowX = CGFloat(offset.x)
        let shadowY = CGFloat(offset.y)
        shape
            .fill(Color.dungeonStone.opacity(fillOpacity))
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(sheenAlpha), Color.white.opacity(0)],
                        startPoint: .topLeading, endPoint: .center
                    )
                )
            )
            .overlay(shape.strokeBorder(accent?.opacity(0.45) ?? Color.dungeonAsh, lineWidth: 1))
            .shadow(color: Color.black.opacity(shadowAlpha), radius: 8, x: shadowX, y: shadowY)
    }
```

(The alphas are unchanged: 0.045 and 0.35 for the sheen, 0.32 and 0.07 for the shadow. Only the sheen's start point and the shadow's offset move, from `.top` and `(0, 3)` to `.topLeading` and `(0.78, 2.90)`.)

- [ ] **Step 2: `GoldPlate`.** In `GoldPlate.body`, add the three lets after `let shape = ...` and replace the last modifier:

```swift
        let offset = LightSource.shadowOffset(depth: 2)
        let shadowX = CGFloat(offset.x)
        let shadowY = CGFloat(offset.y)
```

```swift
        .shadow(color: Color.goldRim.opacity(0.35), radius: 3, x: shadowX, y: shadowY)
```

(was `x: 0, y: 2`; now `(0.52, 1.93)`. The plate's gradient, bevel and rim are untouched.)

- [ ] **Step 3: `UndoPill`.** At the top of `body`, before `Button(action: onUndo) {`, add:

```swift
        let offset = LightSource.shadowOffset(depth: 4)
        let shadowX = CGFloat(offset.x)
        let shadowY = CGFloat(offset.y)
```

and replace `.shadow(color: .black.opacity(0.35), radius: 10, y: 4)` with:

```swift
            .shadow(color: .black.opacity(0.35), radius: 10, x: shadowX, y: shadowY)
```

(now `(1.04, 3.86)`.)

- [ ] **Step 4: Verify and commit.** CI's `build-and-analyze` must pass. Then:

```bash
git add ios/PurgeQuest/Views/Components/DungeonSurface.swift ios/PurgeQuest/Views/Components/GoldButtonStyle.swift ios/PurgeQuest/Views/Components/UndoPill.swift
git commit -m "Panels, the gold plate and the Undo pill: sheen from the lit corner, shadows along the light"
```

---

### Task 4: `litEdge`, on the combat HUD and the Delete and Keep buttons

**Files:**
- Create: `ios/PurgeQuest/Views/Components/LitEdge.swift`
- Modify: `ios/PurgeQuest/Views/Combat/CombatHUD.swift`
- Modify: `ios/PurgeQuest/Views/Combat/CombatView.swift` (`decisionButton`)

**Interfaces:**
- Consumes: `LightSource.highlightPoints(shiftDegrees:)`, `LightSource.rimHighlightAlpha`, `LightSource.rimShadeAlpha`.
- Produces: `View.litEdge(cornerRadius: CGFloat) -> some View`.

- [ ] **Step 1: Create `LitEdge.swift`.** It mirrors the recipe `ExhibitFrame.frameBackground` uses (a 1 pt stroke along `LightSource.highlightPoints()`, white then clear then black):

```swift
//
//  LitEdge.swift
//  PurgeQuest
//
//  The faint rim a flat tile takes from the torch: a 1 pt line that is white on the side the light comes from, clear
//  in the middle and black on the far side. It is the recipe ExhibitFrame already uses for the combat card's frame,
//  with the same end points from `LightSource`, so every lit edge in the app agrees (design:
//  docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md, section 4.2).
//
//      .litEdge(cornerRadius: 12)
//
//  One alpha pair serves both appearances: the highlight shows on a dark tile and the shade on a light one.
//

import SwiftUI

private struct LitEdge: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let points = LightSource.highlightPoints()
        let litStart = UnitPoint(x: CGFloat(points.start.x), y: CGFloat(points.start.y))
        let litEnd = UnitPoint(x: CGFloat(points.end.x), y: CGFloat(points.end.y))
        let colors: [Color] = [
            Color.white.opacity(LightSource.rimHighlightAlpha),
            Color.white.opacity(0),
            Color.black.opacity(LightSource.rimShadeAlpha)
        ]
        let rim = LinearGradient(colors: colors, startPoint: litStart, endPoint: litEnd)
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(rim, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

extension View {
    /// A faint rim from the torch: lit on the top left, shaded on the bottom right. Draws inside the view's bounds.
    func litEdge(cornerRadius: CGFloat) -> some View {
        modifier(LitEdge(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 2: `CombatHUD`.** Three insertions, nothing else changes.

The bar: after the `.background( ... )` that ends the `body`'s `HStack` chain, add `.litEdge(cornerRadius: 12)`:

```swift
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonVoid.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1))
        )
        .litEdge(cornerRadius: 12)
```

The exit button: between its stroke overlay and `.foregroundStyle(.textPrimary)`:

```swift
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                .litEdge(cornerRadius: 10)
                .foregroundStyle(.textPrimary)
```

The combo badge: after its `.background( ... )` and before `.accessibilityElement(children: .ignore)`:

```swift
        .litEdge(cornerRadius: 8)
```

- [ ] **Step 3: `CombatView.decisionButton`.** Between the stroke overlay and `.foregroundStyle(ink)`:

```swift
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(edge, lineWidth: 1))
                .litEdge(cornerRadius: 12)
                .foregroundStyle(ink)
```

- [ ] **Step 4: Verify and commit.** CI's `build-and-analyze` must pass. Then:

```bash
git add ios/PurgeQuest/Views/Components/LitEdge.swift ios/PurgeQuest/Views/Combat/CombatHUD.swift ios/PurgeQuest/Views/Combat/CombatView.swift
git commit -m "litEdge: the combat HUD and the Delete and Keep buttons take the torch's rim"
```

---

### Task 5: Docs

**Files:**
- Modify: `docs/design/DESIGN_SYSTEM.md`
- Modify: `docs/design/UI_ASSESSMENT.md`

- [ ] **Step 1: `DESIGN_SYSTEM.md` Direction.** Replace the paragraph's last two lines so it reads:

```
A torchlit vault. A charcoal (or parchment) canvas, engraved Cinzel capitals for titles, and the
brand gold used sparingly as the one thing that glows. Depth comes from light, not color: one torch
at the top left (`LightSource`), a faint sheen from the lit corner of a panel and a low shadow that
falls along the light.
```

- [ ] **Step 2: `DESIGN_SYSTEM.md` rule 11.** After rule 10 (`10. **Check all four looks**: Light and Dark, Classic and Verdigris.`) add:

```
11. **One torch.** Every lit surface takes its light from `LightSource`: the canvas's gold torch (top edge,
    30% across), a panel's sheen from the lit corner, shadows offset along the light
    (`LightSource.shadowOffset`), and `.litEdge(cornerRadius:)` on flat tiles. Do not hand-roll a sheen or a
    shadow offset.
```

- [ ] **Step 3: `UI_ASSESSMENT.md` decisions.** After the D8 row, add:

```
| D9 | May an atmosphere tint the canvas (workstream 2) | **No tint: light and weight only** (owner, 28 November 2026) | An environment changes the torch's strength, the vignette, a neutral haze or motes, never a hue. Rule 9 and the family-hue rule stand; rule 8 is amended by the sub-project that adds motes, and only for them. |
| D10 | Strength of the canvas torch in Dark (workstream 2) | **Glow**: the brand's mid-plate gold at 8% at its centre (owner, 28 November 2026) | The old pool was drawn in the gold plate's dark-brown ink: about two levels at the top edge in Dark, and a stain in Light. Part 1 of `docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md`. |
```

- [ ] **Step 4: Commit.**

```bash
git add docs/design/DESIGN_SYSTEM.md docs/design/UI_ASSESSMENT.md
git commit -m "Docs: one torch (rule 11), and decisions D9 and D10"
```

---

### Task 6: Open the PR and read CI properly

- [ ] **Step 1: Push** `claude/combat-card-experience-txizxr` and open the PR (ready for review, not a draft) against `main`; subscribe to its activity. Describe what is verified and what is not: written with no Swift toolchain, CI is the first compile.
- [ ] **Step 2: Read each job's steps** with `list_workflow_jobs`: `guard`, `swift-pure-logic` (473 tests in 35 suites), `assets`, `build-and-analyze`, `unit-tests` (the onboarding reset test must have run), `tour`. A cancelled or missing run is not a pass, and a `check_suite.completed` event does not cover cancelled suites.
- [ ] **Step 3: Update the PR description** with the real results, and send the owner the tour's before and after of the torch in Dark and Light.
- [ ] **Step 4: If CI is red,** find the root cause and fix it; never skip or disable a test.

---

## Self-review

**Spec coverage.** 4.1 (the torch, its colour and strength, Light's far shade): Task 1 (numbers) and Task 2 (canvas). 4.2 (panels, plate, pill, litEdge and where it goes): Tasks 3 and 4. 4.3 (invariants: no motion, contrast, no photo, the card unchanged): Global Constraints, the contrast test in Task 1, and no task touches the card or any motion. 6 (tests, the tour): Task 1's five tests and Task 6. 7 (rollout, doc amendments): Task 5. 4.4 and 8 (not in scope): nothing in any task touches the vignette in Dark, layouts or elevation.

**Placeholders.** None: each step shows its code or its exact command.

**Type consistency.** `torchX`, `torchReach`, `farShadeReach` are `Double` and are wrapped in `CGFloat(...)` once, in Task 2; `torchAlpha(isDark:)` returns `Double` and `torchColor(isDark:)` returns `ThemeRGB`, wrapped in `Color(...)` in Task 2; `rimHighlightAlpha` and `rimShadeAlpha` are `Double`, used in Task 4; `shadowOffset(depth:)` returns `(x: Double, y: Double)`, wrapped in `CGFloat(...)` in Task 3. The five test names are used only in Task 1, and the README's 473 is the 468 plus those five.
