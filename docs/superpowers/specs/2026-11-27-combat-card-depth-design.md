# Combat card depth, family skins and commit feedback (design)

**Status:** design approved by the owner section by section on 27 November 2026; the written spec awaits the owner's review. Revised the same day to close five gaps the owner asked to have closed (section 11). No code yet. Nothing merges without the owner's explicit ask.

**Source:** the owner's "Deep-dive UI/UX specification" of 27 November 2026, section 1 ("Combat Card Experience") and the combat-card parts of sections 6 and 7. That spec has seven workstreams; this document designs **the first only**. The others (atmosphere and light, celebrations and hero presence, dashboard, sound and haptics, onboarding, material and typography and share card) each get their own design, in the order the owner's spec gives.

## 1. Decisions recorded

| # | Decision | Chosen | Date |
|---|---|---|---|
| D7 | The 27 November spec versus the older rules (`DESIGN_SYSTEM.md` rule 8 "no loops, no pulses"; the assessment's "family hues only in the Bestiary"; E-7 "no idle animation"; E8 "three moments only") | **The new spec supersedes them.** Amended narrowly here: only what this sub-project uses (section 8). Later sub-projects amend more when they need to | 27 Nov 2026 |
| D8 | Build approach for family skins | **Procedural SwiftUI** (a pure model plus `Canvas`, gradients and `TimelineView` layers). No new art, no Metal, no new project registration. A `FamilySkin` seam lets one family move to a shader later | 27 Nov 2026 |

**Terms and additions to the owner's spec, stated plainly.** The action word is **Keep**, the app's own wording; the owner's spec says "Spare". **Low Power Mode** is added to the Reduce Motion gate; the owner's spec does not mention it.

## 2. Goal

The card is the product. Make the moment of judging a photo feel physical (a photo lifting off a carved frame, a decision that lands), make the six monster families visible in peripheral vision, and let the combo be felt on the card, **without** ever altering the picture the user is deciding about and without changing gameplay, timing or the economy.

**Where it starts.** The card is already rebuilt (sub-plan 1.2, PRs #42 and #43): `ExhibitFrame` (a bronze `goldPlate` gradient rim, an accent stroke, a glass size and age chip), `Nameplate`, equal Delete and Keep buttons, the Undo pill, a coach mark. Today it tilts in 2D only (`rotationEffect`, drag width / 18 degrees), shows a full-card 45% colour wash plus the DELETE and KEEP stamps while dragging, and snaps away on a spring with the delete or keep callback fired 220 ms later.

## 3. Architecture

### 3.1 A pure model, `Models/CardFX.swift`

Foundation only, so it joins the Linux harness (add it to both lists in `tools/swift_harness/run.sh`) with `PurgeQuestTests/CardFXTests.swift`. Views render what it decides; they decide nothing.

| Type | What it holds |
|---|---|
| `SwipeProgress` | The drag against the 110 pt threshold: signed progress from -1 (full delete) to +1 (full keep), the tilt angles (Y up to 10 degrees, X up to 8), the lift (0...1, from drag distance), the delete-side **pull** offset (section 4), and an **armed** flag with hysteresis: it arms at 100% of the threshold and disarms below 90%, so jitter at the threshold cannot repeat a haptic |
| `ComboTier` | From `ComboMultiplier.tenths`: a continuous intensity 0...1 (0 at x1.0), `isHot` from x1.5, `isMax` at x2.0 |
| `ComboCue` | `.raised`, `.cooled` or `.none`, from the multiplier before and after a decision |
| `FamilySkinKind` | An exhaustive map from `MonsterFamily` (six cases) |
| `FXGate` | `.live` or `.still`: `.still` when Reduce Motion or Low Power Mode is on |
| `SeededGeometry` | Deterministic crack, notch and chip positions from the item id, in bounds |
| `LightSource` | One constant: the torch sits at top-centre, 15 degrees left of vertical, so the light direction on screen is the unit vector (sin 15, cos 15) = (0.26, 0.97), y down. The bevel highlight, the frame and photo shadow offsets and the glint line all read it; tilt shifts the highlight angle by up to 20 degrees. Sub-project 2 (atmosphere and lighting) may change the value, never the call sites |

### 3.2 View layers

New folder `ios/PurgeQuest/Views/Combat/CardFX/` (the Xcode project uses synchronized folder groups, so new files register themselves). Back to front: shadow, frame with the skin's edge layer, the lifted photo, the edge band (family dust and combo glow), the drag overlays, then stamps and badges. `ExhibitFrame` takes the skin; `SwipeMediaCard` hosts the layers and feeds them the model.

### 3.3 Invariants every layer obeys

1. **At rest, the photo interior is never tinted, desaturated, blurred or covered.** Skin effects live on the frame, the mat, the outer glow, and a band of at most 8% at the photo's edge, at all times. The one bounded exception is the drag overlays (section 4): they exist only while a finger is down and `EdgeOverlay` limits them, the tear to 34% of the card's width and the barrier to 24%, at most 0.55 and 0.5 alpha at the edge and fading to nothing inward. The user decides on that image, and the elevation plan's principle is that the photo is seen whole. This narrows the owner's spec on purpose: no Clutter Undead desaturation, no Glitchborn scan lines over the photo, no letterbox bars, no Live Photo after-image.
2. Every FX layer is `accessibilityHidden` and `allowsHitTesting(false)`. The VoiceOver Keep, Delete and adjustable actions are untouched.
3. Under `FXGate.still`, every skin renders a still and every cue has a deliberate reduced version (section 3.4), so state changes are still communicated. **The sense of lift never goes away:** the photo's scale and shadow follow the finger without easing.
4. Only the front card animates. The back card keeps its 0.94 scale and renders the still skin with no tilt.
5. Budget: at most 24 particles per skin and one `TimelineView` per card.
6. **Gameplay timing does not change.** `onDelete` and `onSpare` still fire 220 ms after the commit (80 ms under Reduce Motion), as today, so undo, the view-model tests and the economy are unaffected. Nothing here touches HP, XP, gems, combo rules or quests.

### 3.4 Reduced versions under `FXGate.still`

Haptics are silenced by Reduce Motion today (`HapticsService`), and that stays, so a reduced cue must be visible without them.

| Cue | Live | Reduced (Reduce Motion or Low Power) |
|---|---|---|
| Tilt | `rotation3DEffect`, Y 10 degrees, X 8 | Off |
| Lift | Photo scale 1.03 and shadow follow the finger | **Kept**, unchanged: it is the drag itself, not decoration |
| Threshold detent | 150 ms scale punch, overlay opens, haptic | No punch. The armed state is shown instantly: the tear is at its widened shape or the barrier at its locked brightness, and the DELETE or KEEP stamp jumps to full opacity and scale |
| Pull into the tear | Section 4 | Off |
| Commit | Spring snap-away | Unchanged. Under Reduce Motion it is the existing 80 ms snap; Low Power keeps the spring, since it costs nothing and changing it would change timing for those players |
| Combo glow, raise and cool | One-shot pulse, 400 ms cooling fade | A 150 ms cross-fade of the rim to the new tier's glow: opacity only, no scale or movement. The state change is still seen |
| Sheen at x2.0 | One sweep per card | No sweep; the steady inner line and peak glow already mark the tier |
| Family edge layers | Particles, ghost outlines, glitch blocks, jitter | Off; the frame treatment (scales, cracks, notches, thickness, glow) stays |
| Video breath | 1.0 to 1.015 over 4 s | Off; the vignette stays |
| Live Photo reveal | Circular iris from the LIVE badge | The existing 200 ms cross-fade |

## 4. Depth, drag and commit

- **Tilt.** `rotation3DEffect` on top of the existing z-rotation (which stays: the assessment lists the swipe physics as a keeper). Y tilts up to 10 degrees with horizontal drag, X up to 8 degrees with vertical drag, perspective about 0.6. Off under `FXGate.still`.
- **Lift.** The photo scales to 1.03 and its shadow grows as the drag grows; the frame gets the heavier shadow; the frame's inner bevel highlight shifts with the tilt. Shadow offsets and the highlight angle come from `LightSource`. Lift stays under `FXGate.still`.
- **Threshold detent.** On arming: a haptic (a sharp transient for delete, a soft one for keep: two new `HapticsService` methods, both still silenced by Reduce Motion as today), a 150 ms scale punch, and the overlay "opens". Dropping below 90% disarms silently.
- **Pull into the tear (delete only).** Past the arming point the card is drawn a little toward the tear: the displayed offset adds 0.25 of the distance beyond the threshold, capped at 24 pt. It is cosmetic. The gesture's raw translation still decides the commit, so nothing about when a decision registers changes. Keep has no pull: the barrier holds the card, it does not draw it. Off under `FXGate.still`.
- **Overlays, edge-weighted.** The full-card 45% wash is removed (it tints the photo).
  - **Delete:** a jagged crimson void tear grows from the left edge, at most 34% of the card's width, strongest at the edge and fading inward; on arming the tear widens.
  - **Keep:** a brass barrier along the right edge, at most 24% of the width, that brightens and locks on arming.
  - The DELETE and KEEP stamps stay. **Colour default (veto-able):** the barrier is brass but the KEEP stamp stays patina, so the Keep button, the stamp and the word keep one meaning.
- **Not included:** the owner's spec lists an optional soft particle burst at commit. It is left out of the first PR (only Behemoth stone chips fire on commit); revisit once the tour shows whether the tear and barrier land on their own.

## 5. The six family skins

Hue comes from `family.accentColor` (the Bestiary tokens), so the card and the Bestiary agree. The spec's hue words are swapped for two families relative to the code (the app has Undead amber and Relics jade); when D5 turns Glitchborn orchid, the skin follows.

| Family | Frame treatment | Edge layer (front card, gated) | Nameplate tone |
|---|---|---|---|
| Duplicate Dragons | Overlapping scale-arc pattern on the rim; a silver-gold glint line that tracks the tilt | A few scale flakes peel off the frame while dragging | Heavier weight, wider tracking |
| Clutter Undead | Worn, chipped bronze rim; the vignette sits on the mat, not the photo | Up to 12 slow motes rising in the card margin | Drier: lighter weight, tight tracking |
| Archive Relics | Cracked-stone hairlines across the rim; one static diagonal light band at a corner | Up to 10 dust motes drifting very slowly | Quiet: small-caps eyebrow |
| Storage Behemoths | Rim 3 pt thicker with heavy bevel and rivets | None; pressure cracks appear past 60% drag, stone chips on commit | Wide, heavy |
| Video Phantoms | Cool soft glow behind the frame; glassy rim | Two fading ghost outlines trail the frame during a drag; up to 8 soft wisps | Inner glow, never transparent text |
| Glitchborn | Rim with 3 to 4 notched, offset segments; the chromatic split is on the frame stroke only, in `glitchRose` and `videoSapphire` (no new hues) | A flick of up to 6 glitch blocks in the margin about every 1.8 s for 90 ms; one glyph occasionally jitters 1 to 2 pt | The jitter has a still version for the gate; VoiceOver reads normal text |

Nameplate tone is typography and glow only; text never drops below the 4.5:1 contrast gate. The still skin also applies to `DuplicateGroupCard` (a Duplicate Dragons frame, no drag effects, since the group card has no swipe). Each family has a kill switch that falls back to today's frame, so one skin that tunes badly does not block the others.

## 6. Combo, video and Live Photo

**Combo on the active card** is event-driven, with no continuous loop.
- The rim glow follows `ComboTier`: none at x1.0, rising to a steady brass glow at x1.9; from x1.5 a thin second inner line.
- A deletion that raises the multiplier gives the next card one 250 ms brightness pulse as it arrives.
- At x2.0 each card gets a single metallic sheen sweep as it settles (500 ms, once per card).
- **Keep cooling:** when a keep lowers the multiplier, the next card's rim plays a 400 ms fade from brass to ash and settles at the lower tier. No punitive text; the HUD already shows the number.
- `CombatView` compares the multiplier before and after a decision and passes the `ComboCue` into the card (keyed to the card id). Cues come only from the delete and keep paths: **undo emits `.none`**, and a shade delete (which does not raise the multiplier) emits `.none`.

**Video.** While the loop preview plays: a soft vignette (at most 10% alpha, in the outer 8% band) and a breath of 1.0 to 1.015 over 4 s (a loop, gated). No letterbox bars: they would cover picture content.

**Live Photo.** Tapping to play gives a 220 ms brass frame glow and reveals the playback layer through an expanding circular mask from the LIVE badge corner instead of the opacity toggle; stopping reverses it. No after-image trail (it would need extra image layers and would tint the photo).

## 7. Testing and verification

**Harness tests (`CardFXTests`, run by CI's Linux job):** progress clamping and sign; the arm and disarm hysteresis table; tilt clamp (Y 10, X 8), and zero under `.still`; lift non-zero under `.still`; the pull offset (zero below arming, 0.25 of the excess after it, capped at 24 pt, delete side only, zero under `.still`); `LightSource` a unit vector; `ComboTier` at tenths 10, 14, 15, 19 and 20; raised, cooled and none detection; `FamilySkinKind` covering every `MonsterFamily.allCases`; seeded geometry deterministic and in bounds.

**Tour additions (`AppearanceTourUITests`, `UITestSupport`):**
- A launch flag forces a family onto the first card, so the tour shoots all six in Light and Dark.
- Mid-drag shots hold the card at partial and armed positions, left and right.
- **Photo-interior pixel diff:** the same card with skins on and off must be identical inside the photo's interior, at rest (no finger down). This enforces invariant 1 automatically.
- Nameplate text contrast measured from pixels for every family and theme, at least 4.5:1.

**Not verifiable here, and not claimed.** This container has no Swift toolchain, so nothing compiles or runs locally; the first compile is the owner's CI. The following need a device pass by the owner: frame rate during a drag with a skin running on the oldest supported phone, thermals, Reduce Motion, Low Power Mode, VoiceOver, Dynamic Type at the largest size.

## 8. Rollout and doc amendments

**Three PRs, each standalone, none changing gameplay or economy:**
1. **Depth and commit feel:** `CardFX` and its tests, tilt, lift, bevel, the detent with two haptics, and the edge-weighted overlays replacing the wash.
2. **Family skins:** frame, edge layer and nameplate tone for all six, plus the still skin on `DuplicateGroupCard`, with per-family kill switches.
3. **Combo cues and video and Live Photo.**

**Amendments, kept narrow (D7):**
- `DESIGN_SYSTEM.md` rule 8 allows ambient motion on the front combat card's family edge layer and the video breath, always gated by Reduce Motion and Low Power, and nowhere else.
- The assessment's section 7.3 family-hue rule also allows family hues on the combat card's frame and edge layer; still never on chips or controls, and never on the photo.
- `UI_ASSESSMENT.md` records D7 and D8; the E-7 motion budget in the visual-elevation plan is updated to match.

## 9. Not in this design

Sound; the hero companion in combat; atmosphere and the consistent light source; celebrations; the dashboard and "Enter the Dungeon"; onboarding; the share card; typography and material systems. Each is a separate design. Where one overlaps an existing plan (the dashboard with E5 and 1.4, onboarding with 1.5), that design reconciles with the plan first.

## 10. Risks

| Risk | Mitigation |
|---|---|
| The procedural skins look cheap or flat | Per-family kill switch; budget two to three tour passes per family; shaders stay a later option through the `FamilySkin` seam |
| Frame rate or heat on older phones | Front card only, a particle cap, a single `TimelineView`, a Low Power gate; a device pass is a stated acceptance gate |
| Code that has never compiled lands on the owner's CI | Three small PRs; the pure model is separately testable; each PR's description says what was and was not run |
| Effects bias a deletion decision | Invariant 1, enforced by the pixel-diff check |
| The brass barrier and patina stamp read as two colours for one gesture | Called out as a veto-able default; judged on the mid-drag tour shots |

## 11. Revision: five gaps closed (27 November 2026)

After comparing this design with the owner's spec, the owner asked for these gaps to be closed. Where each landed:

| Gap | Fix | Section |
|---|---|---|
| "Card begins to be pulled into" the tear was not designed | A cosmetic delete-side pull past the arming point; the commit rule is untouched | 4 |
| The sense of lift under Reduce Motion was not kept explicit | Lift follows the finger and stays under `.still` | 3.3, 3.4 |
| Combo cues had no deliberate reduced version | A cue-by-cue table of live and reduced versions; combo changes become a short cross-fade | 3.4 |
| The bevel's light direction was not tied to a shared source | One `LightSource` constant read by the bevel, shadows and glint | 3.1 |
| X tilt was 6 degrees, below the owner's 8 to 12 | X tilt is 8 degrees (Y stays 10) | 3.1, 4 |

Two things the first version did without saying so are now stated in section 1: the action word "Keep" instead of "Spare", and Low Power Mode in the gate.

## 12. Errata found while planning PR 1 (27 November 2026)

Two inconsistencies in this document, found when the first PR was planned against the real code. Both are corrected in place above; this section records what changed and why.

1. **Invariant 1 versus the drag overlays.** As first written, invariant 1 said only an 8% edge band may touch the photo, yet section 4 let the delete tear reach 34% of the card's width, which overlaps the photo while a finger is down. The owner's own spec asks for overlays that are "edge-weighted and semi-transparent until the very end of the drag". Invariant 1 now applies to the photo **at rest**; the drag overlays are the one bounded exception (34% and 24% of the width, edge alpha at most 0.55 and 0.5, fading to nothing inward, only while dragging). The skins-on and skins-off pixel diff in PR 2 compares the card at rest.
2. **Commit timing.** Invariant 6 said the callback fires 220 ms after the commit; the code fires it after 80 ms under Reduce Motion. Section 3.4 also put Low Power in the commit row, which would have changed timing for those players. Timing is now stated as it is (220 ms, 80 ms under Reduce Motion) and the commit's snap is tied to Reduce Motion only.

## 13. What parts 2 and 3 built, and where it differs from sections 5 and 6 (27 November 2026)

Built as one PR (plan: `docs/superpowers/plans/2026-11-27-combat-card-depth-pr2-3.md`). The differences, stated plainly:

- **Where things are drawn.** The rim treatments, the combo rim and the Live Photo glow are drawn in the frame's background, which sits behind the photo, and the skins clip to the rim ring besides. The edge layer clips to two 10 pt bands at the card's sides before it draws anything. `CardSkinInvarianceTests` renders all six skins with the combo rim and the glow switched on and requires every pixel inside a flat photo to equal the plain card's, and also requires the dressed card to differ somewhere so the test cannot pass by drawing nothing.
- **Clutter Undead.** Section 5 put a vignette "on the mat". Built: worn chips and speckle on the rim, no vignette.
- **Archive Relics.** "One static diagonal light band" is built as a light band in one corner; there are no rays.
- **Video Phantoms.** The two after-image outlines are clipped to the side bands with everything else, so only the part of each outline inside a band shows.
- **Storage Behemoths.** Pressure cracks grow on the rim from 60% of the drag; stone chips are thrown outward in the bands when the card commits. The chips are the only thing that starts on a commit, and the commit itself is unchanged.
- **One `TimelineView` per card** holds for every skin except Glitchborn, which has two at 30 Hz: the edge layer and the nameplate's one-glyph jitter, because the nameplate is outside the edge layer's canvas.
- **The duplicate card** gets the still Duplicate Dragons frame only. It has no swipe, so no combo rim and no edge layer.
- **Combo.** The glow, the inner line from x1.5, the arrival pulse, the one sheen at x2.0 and the fade after a keep are as designed. A keep that takes the multiplier down to x1.0 shows a brief ash fade although no glow is left to cool, so its cost is felt there too.
- **Live Photo.** The iris opens from a fixed point near the card's top-left corner, an approximation of where the LIVE badge sits; the badge moves when an Elite badge is also shown.
- **Hues.** Every skin colour is `family.accentColor` or the existing `glitchRose` and `videoSapphire`; no new hues and no new image assets.

**Not verified.** No one has seen any of this rendered, and every constant (arc sizes, counts, alphas, speeds, positions) is a first guess. `testZFamilySkins` shoots each skin on the first card in Light and Dark, and `testZCardDragPoses` shoots the drag; those screenshots are how the owner judges the look. Frame rate with a skin running, thermals, Reduce Motion, Low Power Mode, VoiceOver and Dynamic Type still need a device pass.
