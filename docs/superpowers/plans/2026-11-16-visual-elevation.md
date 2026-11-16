# Visual elevation: the plan (no code yet)

**Status:** plan only. Approved in direction by the owner on 16 November 2026 after reviewing the before and after mockups ("heading towards a better UI/UX feel. I approve"), and the eight decisions in section 8 were then settled as recommended. Nothing here is built. Every work package below needs its own go-ahead before code, and nothing merges without the owner's explicit ask.

**Goal:** make the app feel like the product it claims to be, a torchlit vault where clearing clutter is a small, satisfying game, without losing what Phase 0 and 1.1 just made clear. The first aesthetic critique scored the app about 6 of 10: coherent and tidy, but an accounting screen in a fantasy costume. Target: 7 or more on the same critique, then keep going.

**Source documents:** `docs/design/UI_ASSESSMENT.md` section 7 (visual direction and tokens), section 10 (handoff specs), section 11 (roadmap) and `docs/design/DESIGN_SYSTEM.md` (rules). This plan does not replace them. Where the mockups differ from them it says so (section 7 below), and the assessment's token values win over the approximate ones used in the mockups.

## 1. What was approved

Mockups, each as the real current app (left) against the proposal (right). Files in `docs/design/mockups/`:

| File | Shows |
|---|---|
| `elevation-combat-dark.jpg`, `elevation-combat-light.jpg` | The card as an exhibit in a frame, a monster nameplate, equal-weight Delete and Keep, no reward on the card |
| `elevation-library-dark.jpg`, `elevation-library-light.jpg`, `elevation-library-verdigris.jpg` | The hero as the subject in a torch-lit alcove, the gold plate as the one glow, storage demoted to a compact ledger; also in the Verdigris palette that decisions D2 and D4 move to |
| `elevation-room-summary-dark.jpg` | Loot as the headline, every photo a flippable tile, one commit control that says how many and where |
| `before-duplicate-card-and-room-summary.jpg` | The real current duplicate card and Room Summary, Dark then Light, from the E0 tour (left to right: duplicate Dark, summary Dark, duplicate Light, summary Light) |
| `elevation-hero-dark.jpg` | The hero filling the stage, lifetime stats as plaques, gear as sockets, Forge as the one gold action |

## 2. Principles (from the critique and section 7.1)

1. **One light source.** The gold plate is the torch. Gold appears only where something is actionable or earned. One gold control per screen.
2. **The subjects are big.** The hero fills its stage. The monster is announced, not labelled. The user's photo is the exhibit.
3. **Numbers are the reward.** One engraved display numeral (Cinzel Bold, lining, tabular) for XP, gems, combo and stats, larger than its label.
4. **One art language.** Pick one illustration treatment and retire stock symbols from game surfaces (section 8, decision E-3).
5. **Drama in three moments only:** the first card, the delete, the Room Summary. Everything else stays calm. This deliberately loosens design-system rule 8 ("motion is a spring when a value changes, and nothing else") for those three moments, with Reduce Motion fallbacks.
6. **Wording that says what is measured stays.** The storage ledger keeps "estimate", "in Recently Deleted" and "measured" (rule 7). It is restyled, never shortened.
7. **Nothing reads as unfinished.** Empty states tease (silhouettes, ghosted trophies, a line saying how to earn them).

## 3. How it fits the roadmap

The assessment's roadmap already has Phase 1 (clarity), Phase 2 (the system) and Phase 3 (elevation). The owner has decided: 1.0 ships with Phase 0 plus slice A (1.1, 1.2, 1.5); slice B follows. This plan maps onto that, not around it.

| Package | What | Roadmap home | Depends on |
|---|---|---|---|
| E0 | Tour additions: Room Summary, duplicate card, Undo pill, Hero at full size; reset the glossary ledger between tour tests | 1.7 pulled forward | none |
| E3 | Combat card and HUD structure (frame, nameplate, equal buttons, Undo, no reward) | **folded into 1.2** | E0 |
| E1 | Tokens and palette: `PQTokens`, Verdigris Vault and Parchment, ice gems, orchid Glitchborn, lint | Phase 2 | none |
| E2 | Components: `GoldButton`, `Panel`, `Alcove`, `ExhibitFrame`, `Nameplate`, `DisplayNumeral`, `Plaque`, `Socket`, `Ledger`, `Chip`, `ScreenHeader`, `EmptyState` | Phase 2 | E1 |
| E4 | Room Summary | Phase 2/3 | E2, E3 |
| E5 | Library as the Dungeon home | **merges 1.6 and 1.4** | E2 |
| E6 | Hero, Armory, Forge | 1.6 and Phase 2 | E2, E5 (shared stage) |
| E7 | Codex, Trophies, empty states, onboarding art | 1.3, 1.5, Phase 3 | E2 |
| E8 | The three motion moments | Phase 3 | E3, E4 |
| E9 | Polish, Parchment pass, re-shoot App Store screenshots, app icon (D6) | Phase 3 | all |

**Why E3 folds into 1.2.** 1.2 already rebuilds the card's controls (Undo pill, equal-weight Delete and Keep, coach mark, removing the reward preview). Doing the frame and nameplate in the same change means the card is rebuilt once, not twice, and 1.0 ships with the encounter feeling the owner just approved. It uses today's semantic colour names, so the later palette swap (E1) is a token change.

**Recommended order:** E0, then 1.2 with E3, then 1.5 (as already decided); then E1, E2; then E4, E5, E6; then E7, E8, E9. Doing E1 before the screen work means the screens are painted once and re-shot once (the assessment's own risk row).

## 4. Work packages

Sizes use the master plan's scale (S at most half a day, M 1 to 2 days, L 3 to 5 days). Estimates, not measurements.

### E0. Tour additions (S)
Add screenshots the redesign needs and the baseline lacks: Room Summary (the missing "before"), the duplicate card, the Undo pill, the Hero tab at full size, and the Armory with state labels. Reset the glossary ledger between tour tests so the Dive note is shot where intended. Add a photo-library check at the start of the tour that fails with a clear message if the simulator library is empty (the one infrastructure flake seen so far).
**Done (16 November 2026, tour run on `b1e397f`, all six CI jobs green, artifact checked):** `testZRoomSummaryAndDuplicateCard` (runs last, best-effort, plays a room with every card marked for deletion and never confirms, so nothing is deleted) adds `13-duplicate-card` and `14-room-summary` in Dark and Light; each tour launch resets the glossary ledger; the main tour waits up to 30 s for the Library to show photos and fails with a plain message if the simulator library is empty. The two new shots exist in both modes with no notes. They also showed that the current Room Summary already has stat tiles, a three-column photo grid and the commit wording "Move 14 to Recently Deleted, 13.5 MB, recoverable for 30 days", and exposed a bug (section 4, E3). Not added: the Undo pill (it does not exist until 1.2), and Hero and Armory shots (the tour already has `20-hero` and `22-armory`; they are re-shot after the redesign).
**Acceptance:** the tour has a before-shot for every screen in this plan; an empty library fails fast.

### E3. Combat card and HUD (L, inside 1.2)
`CombatView`, `SwipeMediaCard`, `DuplicateGroupCard`, `CombatHUD`.
- `ExhibitFrame`: bronze-gold frame, inner mat, the photo; a glass size and date chip top right. The card keeps its swipe, haptics and accessibility actions.
- `Nameplate`: monster name in Cinzel, rarity and family line, one plain "why" line (`classification.whyText`). Replaces the corner chip and the dark text strip.
- HUD: one slim gold progress line, "Room N of M" and "N left", combo as a display numeral. Hero HP stays hidden (D1).
- The glossary note sits above the frame (as today, restyled); the coach mark from 1.2 replaces it on the first card only (the hazard recorded in the Phase 1 plan: decide which one wins).
- Equal-width Delete (ember) and Keep (surface, patina shield), 56 pt, 44 pt minimum targets; Undo pill above them for five seconds.
- **Must-fix found by E0:** on the Light duplicate card the explanatory line ("Identical file content to another capture…") is near-white on parchment, 1.20:1 (Dark is 10.8:1). It is unreadable, and Phase 0's contrast work never saw it because the tour had no shot. Fixed as part of rebuilding the duplicate card here; the tour shot  is the check.
- No reward preview on the card. The duplicate card keeps its per-copy preview only if the owner says so (open question from 1.2).
**Acceptance:** keep or delete still behaves exactly as before; every control at least 44 pt; Delete and Keep equal in size and both fully on screen at the largest Dynamic Type that fits; contrast at least 4.5:1 for all text; measured on the tour in Light, Dark and Verdigris.

### E1. Tokens and palette (L)
`PQTokens.swift` from assessment 7.3 (the values there win over the mockups'): colour, type, space, radius, elevation, motion. Verdigris Vault and Parchment only (D2), gems ice blue (D4), Glitchborn orchid (D5, rule 9 amended when it lands). `repo_guard` lint: no `.system(size:)` under 12 pt, three radii only, no hand-rolled panel backgrounds, no new hues.
**Acceptance:** all four looks (Light and Dark of the surviving palettes) pass the contrast table; the lint fails the build on a violation; one re-shoot.

### E2. Components (L)
Built once, used everywhere (section 5). Each has a preview and a test where it holds logic (the display numeral's formatting is pure and goes in the harness).
**Acceptance:** no screen hand-rolls a panel, plate, chip or numeral after E4 to E7.

### E4. Room Summary (M)
`RoomSummaryView`, `DecisionTile`.
- **Starting point (from the E0 shot):** "Room 1 / 14 marked, 5 kept", three stat tiles (megabytes to move, XP, gems), a three-column grid of photo tiles with a delete mark, a red "Move 14 to Recently Deleted" bar with "13.5 MB, recoverable for 30 days", and "Keep all, finish dive". So E4 is a restyle and re-hierarchy, not a new screen. **Keep that commit wording** (it is more exact than the mockup's "Delete 7 items", and  pins it); the mockup's button text is illustrative.
- Header "Room cleared". A spoils panel: XP, gems and megabytes to free as display numerals, labelled "paid when you confirm" (rewards stay unbooked until deletion succeeds, as today).
- The grid of tiles (photo, state badge), tap to flip, counts below ("7 to delete", "5 kept").
- Quest progress compact, with the preview that already mirrors the booking (`QuestProgress`).
- One commit control: "Delete 7 items", with "Moves them to Recently Deleted. You have 30 days to get them back." and a quiet "Keep everything instead". The existing wording rule (`Wording`) says how many and where; this keeps it.
**Acceptance:** nothing is deleted without the explicit confirm; the count on the button equals the tiles marked; quest preview unchanged in value; shot in the tour (E0).

### E5. Library as the Dungeon home (L, merges 1.6 and 1.4)
The shared `Alcove` hero stage (1.6) with the hero as the subject; Enter the Dungeon as the one gold plate; the Dive note beneath it; Focused Dive and Hunt Chosen as quiet buttons (they become the one "Choose what to clean" sheet in 1.4); Storage as one compact `Ledger` keeping its three distinctions; the quest list below the fold.
**Acceptance:** the gold plate is the only gold control; the hero is at least a third of the screen height on the smallest supported phone; storage wording unchanged in meaning; the existing 1.4 acceptance still holds.

### E6. Hero, Armory, Forge (L)
Hero tab: the stage fills; lifetime stats become four `Plaque`s (Hero only, per 1.3); gear becomes three `Socket`s; Forge Hero is the gold plate. Armory and Forge: the hero is shown at body size, not a small sprite in a big canvas (design-system rule 1, currently unmet); the chip rows fade at the edge; state labels (Owned, Equipped, Next goal) and full-opacity names for locked items (S-13).
**Acceptance:** rule 1 holds on all three screens; no clipped chips; locked items readable.

### E7. Codex, Trophies, empty states, onboarding art (M)
Empty states tease: silhouetted monsters in the Bestiary ("0 of 36" gets a first-run line), ghosted trophies with the earning rule, an illustration per empty state (the "bespoke line-art" Phase 3 item). Trophies and Settings get the same `ScreenHeader` as the other tabs. Onboarding becomes a full-bleed hero moment with the glow (with 1.5).

### E8. The three motion moments (M)
- **First card:** the frame settles, the nameplate rises.
- **Delete:** a short ember burn on the frame, then the next card; a combo flare when the combo rises.
- **Room cleared:** the spoils count up, tiles settle.
Each at most 400 ms; Reduce Motion replaces them with a fade; haptics as today. No loops, no idle animation anywhere.
**Acceptance:** with Reduce Motion on, nothing moves except a fade; frame rate holds on the oldest supported device (a device pass, not the simulator).

### E9. Polish and ship (S to M)
Parchment pass, the app icon redrawn from the emblem (D6, needs the owner's art direction), the App Store screenshots re-shot from the new screens, a final aesthetic critique.

## 5. Component list

| Component | What it is | Replaces |
|---|---|---|
| `GoldButton` | The gold plate, one per screen; ember and quiet variants | the hand-rolled plates and the olive "Forge Hero" |
| `Panel` | The one surface: lit top edge, low shadow, optional accent border | `DungeonPanelBackground` call sites and hand-rolled fills |
| `Alcove` | The arched stage with the one glow, floor shadow and hero | the small sprite in a card |
| `ExhibitFrame` | Bronze frame, inner mat, glass meta chip | the bare card border |
| `Nameplate` | Plaque with emblem, name, rarity and family, one "why" line | the corner chip and text strip |
| `DisplayNumeral` | Cinzel Bold lining tabular numerals with an optional unit | system digits for rewards |
| `Plaque` | A stat as a display numeral over a small-caps label | the lifetime stats list |
| `Socket` | A gear slot: empty dashed, or the item | the Skin, Weapon, Shield rows |
| `Ledger` | The compact three-column storage readout | the three-row storage card |
| `Chip`, `ScreenHeader`, `EmptyState` | small shared pieces | per-screen variants |

## 6. Quality gates (every package)

- Contrast at least 4.5:1 for text, measured on the tour screenshots, in every surviving look. Tap targets at least 44 pt. No fixed font under 12 pt. Three radii only.
- One gold control per screen; no new hue outside decision D5.
- The tour (E0) shows the screen in Light and Dark and both palettes while two exist; every claim is measured, not judged by eye.
- A fresh aesthetic critique after E5 and after E9, with the target of 7 or more.
- A device pass for motion, Dynamic Type at the largest size, and VoiceOver on the card and the Room Summary (the tour cannot show these).

## 7. Where the mockups differ from the assessment

- Colours: the mockups use today's Classic charcoal (to compare cleanly with the real screenshots) and approximate Verdigris values. The assessment's section 7.3 tokens win. The ice-blue gem hex in the mockup is a stand-in until E1 fixes it.
- Beyond the handoff specs (10.1 to 10.3): the arched alcove, the exhibit frame and the nameplate are new. They extend those specs rather than contradict them; E3 and E5 update the spec text when built.
- The mockup's "COMMON" rarity label and the "Looks out of focus" line are illustrative; the real line is the classifier's `whyText`, and the rarity comes from `MonsterRarity`.
- The hero sprite is the real art enlarged and looks soft; a higher-resolution render is needed for the alcove (open question E-2).
- Inter stands in for SF Pro; Cinzel is the real bundled font.
- The Dates row and the "Next dive" banner are dropped from the Library mockup. Their new homes are an open question (E-4).

## 8. Decisions (owner, 16 November 2026: all eight as recommended)

| # | Question | Decided |
|---|---|---|
| E-1 | Fold the card's new structure (frame, nameplate) into 1.2 so 1.0 ships with it? | Yes, for the card and Room Summary; leave the rest for the first update |
| E-2 | Art: re-render the hero sprites at a higher resolution for the alcove? | Yes; needs the original art source and the licence terms in `docs/CREDITS.md` checked first (an open task inside E5, not yet done) |
| E-3 | One art language: monster portraits, family icons or both? Today they are mixed (glossy shield, cartoon sprites, line icons, SF Symbols) | Line-art family icons plus a bespoke nameplate emblem per family (36 monsters is too many to draw for 1.0) |
| E-4 | Where do the Dates row and "Next dive" go? | Both into the one "Choose what to clean" sheet (1.4) |
| E-5 | Rarity on the nameplate: show it? | Yes, from `MonsterRarity`, in text that is not colour only |
| E-6 | The Armory's gold: it sells things, so is it a primary? | No: gems and prices in brass text, no plate; the plate stays for Enter, Forge and Delete |
| E-7 | Motion budget: allow the three moments above? | Yes, with Reduce Motion fallbacks and a device pass before they ship |
| E-8 | Does Blur Beast keep its name for the catch-all photo? | Rename the catch-all (for example "Gallery Wanderer") so Blur Beast means blurry again. This changes the classifier's catch-all type, the Blur Beast quest and Bestiary text, and any saved records, so it gets its own small plan before it is built |

## 9. Risks

| Risk | Mitigation |
|---|---|
| The card is rebuilt twice | Fold E3 into 1.2 (above) |
| Palette swap invalidates screenshots | E1 before the screen work; one re-shoot |
| The alcove glow and frame look heavy on small phones | Mockups are 402 by 874 pt; measure on the smallest supported size in E0 |
| Motion costs frame rate or feels off | Device pass; three moments only; Reduce Motion fallback |
| Display numerals in Cinzel reduce legibility at small sizes | Used from 12 pt up with tabular lining figures, checked in the tour |
| Scope grows past slice A | E3 and E4 only are proposed for 1.0; the rest waits for the owner's call |

## 10. Not in this plan

No code. No change to the five-tab structure beyond 1.3. No new gameplay or economy. The app icon (D6) is listed in E9 but needs the owner's art direction first. The seasonal event taglines and the widget stay postponed as the owner decided.
