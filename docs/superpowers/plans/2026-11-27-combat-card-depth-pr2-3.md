# Combat card depth, parts 2 and 3: family skins, combo cues, video and Live Photo (implementation plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** plan, 27 November 2026. As in the earlier plans in this repo, the step-by-step code is written just before each task runs; this document fixes the interfaces, the tests and the acceptance for each task. Parts 2 and 3 of the rollout in `docs/superpowers/specs/2026-11-27-combat-card-depth-design.md` (sections 5 and 6) ship together in **one** PR, at the owner's request.

**Goal:** the six monster families look different at the edge of the card, the combo is felt on the front card, and video and Live Photo cards are treated as their own moments, with the photo itself never altered.

**Architecture:** every decision (which skin, where each particle is at time t, the combo tier and cue, glitch timing, crack and ghost amounts) lives in Foundation-only types in `Models/CardSkin.swift`, checked by the Linux harness. Views are thin renderers: a `Canvas` clipped to the frame's rim, a `Canvas` clipped to two 10 pt side bands outside the photo, and a rim-glow overlay. All of it is `FXGate`-aware.

**Tech Stack:** Swift 6 / SwiftUI (`Canvas`, `TimelineView`, `ImageRenderer`), iOS 18, Swift Testing, the Linux harness, XCUITest tour. No new assets, dependencies, Metal or network.

## Global constraints

- Everything in the spec's section 3.3 holds: the photo interior is never tinted, desaturated, blurred or covered at rest; skins draw only on the frame's rim ring and in two 10 pt bands at the card's left and right edges (the photo starts 12 pt in, or 15 pt for Behemoths); every FX view is `allowsHitTesting(false)` and `accessibilityHidden(true)`; only the front card animates; at most 24 particles per skin and one `TimelineView` per card.
- Under `FXGate.still` (Reduce Motion or Low Power): skins render their still frame treatment only (no particles, ghosts, flicks, jitter, chips); combo changes are a 150 ms opacity cross-fade of the rim, no sweep; the video breath is off and its vignette stays; the Live Photo reveal is the existing 200 ms cross-fade.
- Gameplay timing, rewards, combo rules, undo and the economy are untouched. The only view-model change is a read-only `comboCue` set where the multiplier already changes.
- Hues come from `family.accentColor`; the Glitchborn chromatic split uses the existing `glitchRose` and `videoSapphire`. No new hues, no new image assets. Nameplate text never drops below the 4.5:1 text colours it uses today.
- Visible wording: the app says "Keep", never "spare", and "delete", never "purge" (the repo guard checks string literals).
- Pure files are `import Foundation` only, `nonisolated`, listed in both lists in `tools/swift_harness/run.sh`. Tests are Swift Testing.
- No Swift toolchain exists in the authoring container, and CI artifacts (screenshots) cannot be downloaded from it. **CI is the only compile and test, and nobody has seen the visuals.** Every visual constant here is an untuned first guess for the owner to judge on the tour screenshots.
- Nothing merges without the owner's ask. Push only to `claude/purgequest-ui-ux-spec-f7cryw`.

## File structure

| File | Change |
|---|---|
| Create `ios/PurgeQuest/Models/CardSkin.swift` | `FamilySkinKind`, `NameplateTone`, `SeededGeometry`, `EdgeParticles`, `GlitchTiming`, `SkinDrag`, `ComboTier`, `ComboCue` |
| Create `ios/PurgeQuestTests/CardSkinTests.swift` | Harness tests for all of the above |
| Modify `tools/swift_harness/run.sh` | Add `Models/CardSkin` and `CardSkinTests` |
| Modify `ios/PurgeQuest/ViewModels/CombatViewModel.swift` | `comboCue`, set at the three decision sites and cleared on undo and on the three resets |
| Create `ios/PurgeQuest/Views/Combat/CardFX/SkinRim.swift` | The frame treatment for each skin, drawn on the rim ring only |
| Create `ios/PurgeQuest/Views/Combat/CardFX/SkinEdgeLayer.swift` | Particles, ghosts, flakes, chips, cracks, in the side bands only |
| Create `ios/PurgeQuest/Views/Combat/CardFX/ComboRim.swift` | Rim glow, inner line, arrival pulse, sheen, cooling fade |
| Modify `ios/PurgeQuest/Views/Components/ExhibitFrame.swift` | `skin` parameter; extra rim; hosts `SkinRim` |
| Modify `ios/PurgeQuest/Views/Components/Nameplate.swift` | `skin` parameter; tone |
| Modify `ios/PurgeQuest/Views/Combat/SwipeMediaCard.swift` | Skin, edge layer, combo rim, commit chips, video vignette and breath, Live Photo glow and iris |
| Modify `ios/PurgeQuest/Views/Combat/CombatView.swift` | Pass `comboTier` and `comboCue` to the front card |
| Modify `ios/PurgeQuest/Views/Combat/DuplicateGroupCard.swift` | The still Duplicate Dragons frame |
| Create `ios/PurgeQuestTests/CardSkinInvarianceTests.swift` | App unit test: the photo interior is pixel-identical with skins on and off, for all six |
| Modify `ios/PurgeQuest/UITestSupport.swift`, `ios/PurgeQuestUITests/AppearanceTourUITests.swift` | `-UITestFamily`, `-UITestNoSkins`, `testZFamilySkins` |
| Modify docs | Spec, `DESIGN_SYSTEM.md`, `UI_ASSESSMENT.md`, README count |

---

## Task A: the pure model (tests first)

**Produces** (all `nonisolated`, Foundation only):
- `FamilySkinKind: String, CaseIterable { dragons, undead, relics, behemoths, phantoms, glitch }`, `init(family: MonsterFamily)` (exhaustive), `extraRim: Double` (3 for behemoths, else 0), `particleBudget: Int` (5, 12, 10, 0, 8, 6), `isAmbient: Bool` (undead, relics, phantoms, glitch), `nameplateTone: NameplateTone`, and `static let enabled: Set<FamilySkinKind>` (the kill switch, all six on) with `static func active(for family: MonsterFamily) -> FamilySkinKind?`.
- `NameplateTone { weight: Weight (.light .regular .semibold .bold .heavy), tracking: Double, smallCapsEyebrow: Bool, glow: Double }`.
- `SeededGeometry(key: String)` using FNV-1a (never `Hasher`, which is randomised per process) and splitmix64; `value(_ index: Int) -> Double` in `[0, 1)`.
- `EdgeParticle { x, y, radius, alpha: Double }`; `EdgeParticles { static let bandWidth: Double = 10; static func ambient(kind:seed:time:width:height:) -> [EdgeParticle]; static func dragDriven(kind:lift:seed:width:height:) -> [EdgeParticle]; static func chips(kind:progress:seed:width:height:) -> [EdgeParticle] }`.
- `GlitchTiming { static let cycle = 1.8; static func isFlicking(time:) -> Bool (first 5% of a cycle, 90 ms); static func jitterGlyph(time:nameLength:seed:) -> Int? (a flick in every third cycle only) }`.
- `SkinDrag { static func pressureCracks(strength:) -> Double (0 up to 60%, then 0...1 by 100%); static func ghosts(dx:dy:lift:) -> [(dx: Double, dy: Double, alpha: Double)] (two, at 15% and 8%) }`.
- `ComboTier { init(tenths:) clamped 10...20; intensity (0 at x1.0, 1 at x2.0); isHot (from 15); isMax (at 20); glowAlpha; hasInnerLine }` and `ComboCue { none, raised, cooled; static func between(beforeTenths:afterTenths:) }`.

**Tests** (`CardSkinTests`): skin kind covers every `MonsterFamily.allCases`, the six map to six distinct kinds, the kill-switch set is all six; seeded values are deterministic, in `[0,1)`, differ across keys and indices; every particle of every kind, at many times, sizes and seeds, has `x <= bandWidth || x >= width - bandWidth` and `0 <= alpha <= 1`; no kind exceeds its budget or 24; Behemoths ambient is empty; ambient is deterministic and moves with time; glitch particles exist only inside the flick window and change between cycles; jitter is at most one glyph, inside range, and only in every third cycle; cracks are 0 up to 60% and 1 at 100%; ghosts are zero without lift; combo tier boundaries at tenths 10, 14, 15, 19, 20 and clamping; cue is raised, cooled or none.

**Acceptance:** `swift-pure-logic` green. README harness count updated to the real total.

## Task B: the combo cue from the view model

Add `private(set) var comboCue: ComboCue = .none` to `CombatViewModel`. Set it where the multiplier already changes: `decideDelete` (after `afterDeletion()`, from the tenths before and after; the shade path sets `.none`), `decideSpare` (after `afterKeep()`), and `commitGroupDecisions` (from the tenths before the loop and after). Clear it (`.none`) in `undoLastDecision` and at the three places that reset `comboMultiplier`. `CombatView` passes `comboTier: ComboTier(tenths: combat.comboMultiplier.tenths)` and `comboCue: combat.comboCue` to the front `SwipeMediaCard` only (new defaulted parameters, so the back-card call is unchanged).

**Acceptance:** build green; a CI-only test that a keep after deletions gives `.cooled`, a deletion gives `.raised`, a shade or an undo gives `.none` (added to `UndoDecisionTests`' neighbours if the view model can be driven there, otherwise covered by the pure `ComboCue` tests and stated as not run).

## Task C: the rim skins

`SkinRim(kind:, seed:, accent:, highlightShift:)` is a `Canvas` that first clips to the rim ring (the frame's outer rounded rect minus the photo's rounded rect, even-odd), so nothing it draws can reach the photo. Per kind, first-guess treatments from the spec: Dragons overlapping scale arcs and a tilt-following silver-gold glint; Undead seeded chips and speckle; Relics seeded cracks and one static corner light band; Behemoths a heavier bevel with four rivets, rim 3 pt thicker; Phantoms a glassy rim with a cool outer glow; Glitchborn three or four seeded dark notches and a chromatic split of the frame stroke in `glitchRose` and `videoSapphire`. `ExhibitFrame` takes `skin: FamilySkinKind?` (nil is today's frame, so the kill switch is the `enabled` set) and `extraRim` widens the padding. `DuplicateGroupCard` passes `.dragons`.

**Acceptance:** build green; the invariance test (Task G) passes for all six.

## Task D: the edge layer, the nameplate tone, commit chips

`SkinEdgeLayer` is a `Canvas` over the card, clipped to the two side bands, that draws `EdgeParticles` (ambient ones inside a `TimelineView(.animation(minimumInterval: 1/30))` only when the skin is ambient, the card is in front and the gate is live), the Phantoms' two ghost outlines and the Dragons' flakes from the drag (no timer), the Behemoths' pressure cracks past 60% drag, and stone chips when the card commits. `Nameplate` takes `skin:` and applies `NameplateTone` as tracking, weight on the rarity line, small caps on the eyebrow, and an inner glow for Phantoms; Glitchborn jitters one glyph of the name through an `AttributedString` baseline offset during a flick (live gate only; VoiceOver always reads the plain name).

**Acceptance:** build green; invariance test green; with the gate still nothing in the layer moves.

## Task E: the combo rim

`ComboRim(tier:, cue:, gate:, cardID:)` overlays the front card's frame: a steady brass rim glow (`glowAlpha`), a thin second inner line from x1.5, a 250 ms brightness pulse when the card arrives with `.raised`, a 500 ms metallic sheen sweep once per card at x2.0, and a 400 ms brass-to-ash fade when the card arrives with `.cooled`. Under the still gate every change is a 150 ms opacity cross-fade to the new glow level.

**Acceptance:** build green; no `repeatForever`; the sheen and pulses are one-shot per card id.

## Task F: video and Live Photo

While the loop preview plays: a vignette of at most 10% alpha in the outer 8% of the preview, and a breath of 1.0 to 1.015 over 4 s (a loop; off under the gate; the vignette stays). Live Photo: tapping to play gives a 220 ms brass frame glow and reveals `LivePhotoPreviewView` through an expanding circular mask from the LIVE badge corner, reversed on stop; under the gate it is the existing 200 ms cross-fade. No letterbox bars and no after-image trail (spec section 6).

**Acceptance:** build green.

## Task G: the invariance test, the tour hooks, the docs

`CardSkinInvarianceTests` (app unit test, `@MainActor`): for each of the six kinds, render the card composite (the frame with the skin, plus the edge layer at a fixed time, inside the card's 8 pt padding) and the same composite with no skin, over the same gradient photo using `ImageRenderer` at scale 1, and require every pixel inside the photo's interior (inset by the rim plus the 10 pt band) to be identical. Tour: `-UITestFamily <raw>` forces a skin onto the first card, `-UITestNoSkins` turns them off, `testZFamilySkins` shoots all six in Light and Dark. Docs: record in the spec what shipped and what was deferred, amend `DESIGN_SYSTEM.md` rule 8 (ambient motion only on the front card's family edge layer and the video breath, gated) and the family-hue rule (hues on the card's frame and edge layer only, never on chips or controls or the photo), add the matching lines to `UI_ASSESSMENT.md`.

**Acceptance:** `unit-tests` green including the invariance test; the tour shoots the twelve skin screenshots.

## Verification and what is not claimed

CI shows compile (`build-and-analyze`), the pure logic (`swift-pure-logic`) and the invariance test (`unit-tests`). Not verified by anyone: how any skin looks, the frame rate with a skin running, thermals, Reduce Motion, Low Power, VoiceOver, Dynamic Type. Those need the owner's eyes and phone.
