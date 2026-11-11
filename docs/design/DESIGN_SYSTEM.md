# PurgeQuest design system

How the app is meant to look, and the shared pieces that make it so. Colors and their contrast are
defined and tested in `ios/PurgeQuest/Models/ThemePalette.swift`; this file is about composition.

## Direction

A torchlit vault. A charcoal (or parchment) canvas, engraved Cinzel capitals for titles, and the
brand gold used sparingly as the one thing that glows. Depth comes from light, not color: a faint
sheen along a panel's top edge and a low shadow under it.

## Rules

1. **The hero is the subject.** Size the figure, not its canvas: `HeroSpriteView(framing: .body)`
   or `HeroStageView`. A hero should never be a small sprite in a large empty frame.
2. **One primary action per screen, above the fold, on the gold plate** (`.buttonStyle(.gold(…))`).
   Everything else is a quiet panel button.
3. **One panel surface.** `.background(DungeonPanelBackground())`. Pass `accent:` when the panel
   belongs to something (a race, a finished quest, an unlocked trophy); it tints the border only.
   Do not hand-roll `RoundedRectangle().fill(Color.dungeonStone)`.
4. **Three corner radii**: `DungeonRadius.chip` (8), `.card` (12), `.hero` (16, at most one per
   screen). Continuous corners.
5. **One progress bar**: `DungeonProgressBar`. Not `ProgressView`.
6. **Numbers are the reward.** Bold, monospaced digits, larger than their label. Labels are small
   capitals in `.dungeonCaption`; explanations are `.caption2` in the secondary text color.
7. **Wording that says what is measured stays.** The storage ledger's titles and captions separate
   an estimate from a measurement; restyle them, never shorten them.
8. **Motion is a spring when a value changes**, and nothing else. No loops, no drifting, no pulses.
9. **No new hues.** Use the tokens in `Color+Theme.swift`. No neon, pastel or purple. White and
   black appear only at low opacity, as sheen and shadow.
10. **Check all four looks**: Light and Dark, Classic and Verdigris.

## Seeing a change

Open a pull request that touches `ios/PurgeQuest/`. The "UI snapshots" workflow builds the app,
fills the simulator's library with synthetic pictures (`tools/ci/make_library_fixtures.py`) and
uploads every screen of the Light/Dark tour as the artifact `ui-snapshots-tour`, in about fifteen
minutes.

## Not yet brought into line

- The combat card and the Room Summary: now visible in the tour's `11-combat` screenshot, not yet
  redesigned.
- Armory tiles and the Forge's small previews still size the canvas, so the hero is small there.
- Trophies and Settings use the system navigation title; Library, Bestiary and Armory use Cinzel.
- Shop, Forge, Onboarding, Settings and Combat still hand-roll some panel backgrounds.
