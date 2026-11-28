# Atmosphere and light (design)

**Status:** Part 1 (one torch) was approved by the owner on 28 November 2026 and is in implementation. Part 2 (depth and environments) is designed next, section by section, and is not approved yet. Nothing merges without the owner's explicit ask.

**Source:** the owner's "Deep-dive UI/UX specification" of 27 November 2026, section 2 ("Atmosphere & Environmental Polish"), the second of its seven workstreams. The first, the combat card, is built and merged (#46 to #49). This document designs the second only; the other five each get their own design.

## 1. Decisions recorded

| # | Decision | Chosen | Date |
|---|---|---|---|
| D9 | May an environment tint the canvas? The spec asks for "cooler" deeper rooms, a "necrotic" clutter edge and "warmer, dustier" archive light | **No tint: light and weight only.** An environment changes the torch's strength (warm or cool), the vignette's size and edge, a neutral haze (Blur) and motes (Archive, and later rooms). Rule 9 and the family-hue rule stand. Rule 8 gets one narrow exception, for the motes (section 5) | 28 Nov 2026 |
| D10 | How strong is the torch at the canvas's top left in Dark | **Glow**: the brand's mid-plate gold at 8% at its centre. The brightest point lifts about 14 levels of 255 over the unlit canvas | 28 Nov 2026 |

D7 and D8 (`docs/design/UI_ASSESSMENT.md`) still govern: the owner's spec supersedes the older rules, amended narrowly and only where a sub-project uses it; effects are procedural SwiftUI, with no new art, no Metal and no new dependencies.

**Terms and additions to the owner's spec, stated plainly.** Low Power Mode is added to the Reduce Motion gate (`FXGate`), as in the first workstream. The spec says "cooler" and "warmer"; with D9 that means how strong the gold torch is, not a tint.

## 2. Goal

Inside a dive the world feels empty, and the screens do not read as one lit space. Make the torch a light you can see, give every lit surface the same direction, and (Part 2) let a dive darken with depth and take on the character of what is being cleared, without ever taking text contrast below 4.5:1, touching a photo, or changing gameplay.

**A finding that shaped Part 1.** `DungeonBackgroundView` draws its "torch" with `goldInk` (`#2D1702`), the ink printed on the gold plate: a dark brown, not a gold. Measured with the code's own formulas on a 402 x 874 pt screen:

- **Dark, top edge:** no pool (17, 17, 16); today's pool at its centre (19, 18, 15), a shift of about two levels. You cannot see it. That is why rooms 1 and 5 would look the same whatever a depth effect did to a pool nobody can see.
- **Light, top edge:** the canvas (249, 249, 242); today's pool (237, 235, 228), about 13 levels darker. It reads as a stain, not a lamp.
- **Glow, Dark:** gold `#DCBB6A` at 8% with its centre 30% across: (31, 29, 22) at its brightest, about 14 levels over the unlit (17, 17, 16).

Elsewhere the light does not agree with itself. The combat card's frame already follows `LightSource` (15 degrees off vertical, from the top left). Panels are lit straight from above (a vertical sheen and a straight-down shadow). The gold plate and the Undo pill cast straight-down shadows. The combat HUD and the Delete and Keep buttons are flat, with no light cue at all.

## 3. Architecture

Approach A, the shape the combat card used: a pure, Foundation-only model decides every number and thin views draw them. Part 1 grows `LightSource` (`Models/CardFX.swift`, already in the Linux harness). Part 2 adds an `Atmosphere` model beside it. The alternatives were rejected: a dive-only overlay with the torch left in the canvas (the numbers would live in two places, and the overlay cannot dim a torch it does not own), and logic inside the views (nothing to unit-test, and every calibration is a view edit).

The canvas is drawn in 16 places in 15 files, `BarScrims` included. `BarScrims` redraws `DungeonBackgroundView` masked to the screen's top and bottom, so anything the canvas draws, the scrims match for free.

## 4. Part 1: one torch (approved 28 November 2026)

### 4.1 The canvas torch

- **Position and reach.** `LightSource.torchX` = 0.30, a share of the screen's width, on the top edge; left of centre, so light travels right, as the card's does. `LightSource.torchReach` = 420 pt, fading linearly to nothing, as today's pool does.
- **Colour and strength.** Dark: `ThemePalette.Gold.plateStops[2]` (`#DCBB6A`, the brand's mid-plate gold, `Color.goldFill`) at 0.08. Light: `ThemePalette.Gold.bevel` (`#FFF3C9`) at 0.14, a warm wash that does not darken. Its luminance lands within 0.8% of the canvas's, where the pool it replaces was about 12% darker. Both are existing tokens (rule 9), and `LightSource.torchColor(isDark:)` and `torchAlpha(isDark:)` are the one source for the canvas and the tests. The Light numbers are first values, to be set from the tour.
- **Where.** `DungeonBackgroundView` replaces its dark-brown pool. Its `intensity` parameter stays unused until Part 2.
- **Light only: the far corner.** The existing `canvasVignette` tint, radially from the bottom-trailing corner, 0 to `LightSource.farShadeReach` = 520 pt, so the side away from the torch shades a little deeper. Dark keeps the vignette it has.

### 4.2 What responds

Only shared primitives, so about eight code files and no sweep.

| Surface | Change |
|---|---|
| `DungeonPanelBackground` (19 uses in 9 files) | The sheen runs `.topLeading` to `.center` (was `.top` to `.center`; alphas unchanged, 0.045 in Dark and 0.35 in Light). The shadow is offset by `LightSource.shadowOffset(depth: 3)` = (0.78, 2.90), was (0, 3) |
| `GoldPlate` | Shadow offset by depth 2 = (0.52, 1.93), was (0, 2). The plate's art is untouched |
| `UndoPill` | Shadow offset by depth 4 = (1.04, 3.86), was (0, 4) |
| New `.litEdge(cornerRadius:)` | A 1 pt inner stroke: white at `LightSource.rimHighlightAlpha` (0.16) on the lit side, clear in the middle, black at `rimShadeAlpha` (0.16) on the far side, along `LightSource.highlightPoints()`. It is the recipe `ExhibitFrame` already uses for the card, so every lit edge in the app uses one recipe. One alpha pair serves both appearances: the highlight shows on dark surfaces and the shade on light ones |
| Where `litEdge` goes | The `CombatHUD` bar (radius 12), its exit button (10) and combo badge (8), and the Delete and Keep buttons (12). All are flat today |

### 4.3 Invariants

1. **No motion in Part 1.** Rule 8 is untouched.
2. **Text stays readable on the lit canvas.** Measured at the torch's brightest point on `canvasTop`, the lowest contrast in all four looks is 5.3:1 (the dimmest text colour in Verdigris, both appearances, and in Classic Light). Classic Dark's is 5.9:1. The floor is 4.5:1, and a test pins it.
3. **Nothing touches a photo.** The canvas is behind everything, and every layer keeps `allowsHitTesting(false)`.
4. **The combat card is unchanged.** It already follows the light.

### 4.4 Not in Part 1

The vignette in Dark, any screen's layout, elevation levels and materials (workstream 7), the card, and gameplay.

## 5. Part 2: depth and environments (to be designed and approved next)

What the owner's spec asks, and what is already settled:

- **Depth, rooms 1 to 5.** `dungeonIntensity` already runs 0 to 1 across the five rooms in `CombatView` and is ignored by the canvas. A deeper room has a denser vignette and a cooler light. With D9, cooler means a weaker gold torch. The mock the owner saw with the Glow choice had room 5 keep 40% of room 1's torch with the vignette closing in; those numbers are a proposal to confirm, not a decision.
- **Environments.** The four named in the spec, Blur, Screenshots and Clutter, Large Video and Storage, and Old and Archive, match `RoomBucket` (`blur`, `screenshots`, `largeVideo`, `old`) one to one. The auto-chosen `DungeonTheme` has seven values and none for blur. Proposed: the player's focus decides, and the auto theme decides when no focus is set (`clutterCatacombs`, `vaultOfExcess`, `archiveDepths` map onto the same three). The other themes get depth only. Each is light and weight only: Blur a neutral haze and a softer vignette, Clutter a ragged vignette edge, Large Video a heavier vignette, Archive a stronger torch and dust.
- **Motes.** An optional, very faint layer: embers (gold) in later rooms, dust (neutral) for Archive, a small fixed count, stopped under Reduce Motion and Low Power Mode, where they become a still sprinkle. This needs the one narrow amendment to rule 8, recorded by that sub-project (D7).
- **Reduce Motion.** The torch, vignette and haze are static, so they stay under Reduce Motion. Only the motes move, so only they are gated.
- **Testing hooks.** The tour needs launch flags to start at a given room and environment, as `-UITestCombo` did for the combo rim.

## 6. Testing and verification

**Harness tests, in `CardFXTests`** (the Linux job; no new harness entries, since `Models/CardFX`, `Models/ThemePalette` and `CardFXTests` are already listed):

1. The torch sits left of centre, its light travels right, and its reach is positive.
2. Dark's torch strength is the 0.08 the owner chose (a deliberate pin: changing it should take a decision).
3. In both palettes, the torch lifts the Dark canvas's luminance and does not lower the Light canvas's by more than 2% (the pool it replaces lowered it about 12%).
4. Text contrast at the torch's brightest point is at least 4.5:1 for all three text colours in all four looks.

**The tour.** Every screen in Light and Dark already shoots the canvas and the panels, so the existing tour shows Part 1 with no new test. The owner judges from it.

**Not verifiable in the authoring container, and not claimed.** There is no Swift toolchain here, so CI is the first compile. A device pass is the owner's: whether a faint radial gradient bands on an OLED screen, and Reduce Transparency, Increase Contrast and Dynamic Type.

## 7. Rollout and doc amendments

**Two PRs.** PR 1 (this part): one torch, on every screen. PR 2: depth and environments in the dive, once Part 2 is approved.

**Amendments, kept narrow (D7).** `DESIGN_SYSTEM.md` gets a sentence in its Direction paragraph and a new rule 11, "One torch"; no existing rule is relaxed. `UI_ASSESSMENT.md` records D9 and D10. PR 2 will amend rule 8 for the motes, and nothing else.

## 8. Not in this design

The hero companion and celebrations, the dashboard, sound and haptics, onboarding, the share card, the elevation, typography and material systems, any tint from a theme or family colour (D9), a flickering torch, and Metal.

## 9. Risks

| Risk | Mitigation |
|---|---|
| A faint gradient bands on an 8-bit or OLED display (14 levels over 420 pt is a band about 30 pt wide) | Judge the tour at 1:1; if bands show, widen the reach or lower the peak before adding any texture |
| The Light wash is too faint to read as a torch (a warm cast of about 6 blue levels at its centre) | The numbers are first values; set them from the tour |
| The sheen and shadow change is too small to see (an 0.8 pt shadow shift) | The corner sheen and `litEdge` carry the direction; the shadow offset is for consistency |
| Scope creep into workstream 7 (elevation and material) | Only light direction changes here; no level, radius, fill or border changes |
