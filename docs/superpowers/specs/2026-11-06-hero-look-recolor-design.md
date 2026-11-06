# Hero look recolor: armor dye, skin tone and hair color on the sprite

Date: 2026-11-06. Status: implemented. Discussion record: `2026-11-05-hero-look-recolor-discussion.md` (PR #22).

## Problem

On the onboarding "Shape Your Look" page and in the Hero Forge:

- **Armor Dye** drew the dye colour over every armor part (body, arms, hands, legs) at 45% opacity (`.sourceAtop`), outlines and skin included. It read as a translucent blob, not dyed cloth.
- **Skin tone** and **hair color** swatches wrote `skinTone` / `hairColor`, which the sprite renderer never reads (it reads the hue shifts, `armorDye` and `materials`). The only code that read them, `MiniAvatarView.figure`, is unused. The sprite did not change.
- The shading-preserving masked recolor (OKLab, 27 packs of masks) already existed but ran only for human-approved art. Nothing is approved, so it never ran.

## Decision

Recolor the baked parts through the shipped masks. The masks stay `candidate`; this is a recorded exception (README, "Legacy recolor of baked parts") behind `LookRecolorPolicy.candidateMasksMayRecolorBakedParts`, with held-gear masks as the precedent. Composition, `CharacterRenderPlanner` and approvals are unchanged.

## Design

- **Data.** `materials` is the source of truth for skin and hair (`skin.<tone>`, `hair.<color>`); nil is the art as painted, so existing saves do not shift. Armor dye is derived from `armorDye` (which already has a native `.none`) at render time, for body, arms and legs only, and a stored `custom` color wins. A new "As painted" chip clears skin and hair.
- **Planner (pure Swift).** `LegacyRecolorPlanner` turns the resolved colors and the manifest into per-part recolor regions (mask resource, tone). The head's skin is the face window: `anatomy skin mask x (1 - headgear alpha)` plus the headgear skin mask. Bone and stone bodies take no skin or hair, and the planner applies the same availability rules as `LookCapabilities`, so a stored choice never recolors a paint whose control is disabled (a void face, a body with no armor); only the derived dye is gated, not Forge `custom` colors. "As painted" also restores the saved enum to the race default. `LookCapabilities` derives, from the manifest, which controls change anything on a paint, and UI rows that would do nothing are disabled with a reason.
- **Renderer.** `SpriteRenderer.processedPart` runs the hue sliders, then `MaterialRecolorer` applies the plan, caching per part by the regions that part uses. The flat overlay is deleted. The modular path resolves materials the same way, so the dye is not lost when a pack is later approved and never repaints a head.
- **Assets.** Seer 1's body, arms and legs become armor layers (override); Seer 3's head gets authored `hair` and `skin` regions. Both rebuilt with `build_assets.py --packs ... --update-manifest`, then `approvals.py apply`, `checklist.py`, `validate.py`.

## Verification

- Logic is test-first in the Linux harness (`LookRecolorTests`): expected values are literals from the palette, the Python reference (OKLab shading and clamp boundaries) and the shipped manifest; mutation-checked.
- Looks were reviewed offline across all 27 paints with the repo's Python renderer (`scml.render_frame`), including the extremes (near-white and dark dyes).
- The UIKit/SwiftUI changes are compiled and exercised only by Xcode CI.

## Out of scope

Hue sliders (skin hue rotates eyes and brows, hair hue rotates the whole head), eye color, the other inert Forge controls (face, brows, mouth, mood, hair style), the onboarding dye achievement gate, and any approval.
