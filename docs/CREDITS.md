# Third-party art and font credits

Everything in the app that was not made for it: where it came from and the terms it comes under. The
CraftPix, itch.io and font terms below were read on the vendors' own pages on 12 November 2026. Terms can
change, so read them again before each release. Only converted or derived files are in this repo, never the
original packs; keep the original archives out of it. The Credits screen in Settings (About) lists the packs
and shows Cinzel's license; its list is `ios/PurgeQuest/Models/ThirdPartyCredits.swift`, so change both when
a pack is added or dropped.

## CraftPix free downloads

All twelve packs in this section are CraftPix freebies, so the **Freebies terms (section 2) of the
[CraftPix file license](https://craftpix.net/file-licenses/)** apply. In short:

- **Allowed:** any number of personal and commercial projects, modifying the art, and selling games that
  contain it. No credit is required (the license says any credit "will be highly appreciated").
- **Not allowed:** reselling the source files or slightly modified versions of the art; redistributing the
  art so that other users can take the files out of an app (an app that lets the user save or export a
  modified version of the artwork itself is not allowed); and using the art to train, test or improve any
  AI or machine-learning system (section 3).

| Used for | Pack | Where in the repo |
|---|---|---|
| The 27 hero art packs: three characters (v1 to v3) of each of Valkyrie, Necromancer, Seer, Forest Ranger, Dark Oracle, Blood Alchemist, Skeleton Crusader, Skeleton Warrior and Golem | [Free Chibi Valkyrie](https://craftpix.net/freebies/free-chibi-valkyrie-character-sprites/), [Free Chibi Necromancer of the Shadow](https://craftpix.net/freebies/free-chibi-necromancer-of-the-shadow-character-sprites/), [Free Seer Chibi](https://craftpix.net/freebies/free-seer-chibi-character-sprites/), [Free Forest Ranger Chibi](https://craftpix.net/freebies/free-forest-ranger-chibi-character-sprites/), [Free Chibi Dark Oracle](https://craftpix.net/freebies/free-chibi-dark-oracle-character-sprites/), [Free Bloody Alchemist Chibi](https://craftpix.net/freebies/free-bloody-alchemist-chibi-character-sprites/), [Free Chibi Skeleton Crusader](https://craftpix.net/freebies/free-chibi-skeleton-crusader-character-sprites/), [Free Chibi Skeleton Warrior](https://craftpix.net/freebies/chibi-skeleton-warrior-character-sprites/), [Free Golem Chibi 2D Game Sprites](https://craftpix.net/freebies/free-golems-chibi-2d-game-sprites/) (each pack has three characters) | `ios/PurgeQuest/Art/Races/`, and the layers cut from them in `ios/PurgeQuest/Art/Modular/` |
| The 40 staves and 40 shields | [Free Staves 2D Weapon Pack](https://craftpix.net/freebies/free-staves-2d-weapon-pack/), [Free Shield 2D Game Assets Pack](https://craftpix.net/freebies/free-shield-2d-game-assets-pack/) | `ios/PurgeQuest/Art/Gear/{staves,shields}/` |
| Mist, Tatter and Void Wraith monsters (`Monster-*Wraith`) | [Free Wraith Tiny Style 2D Sprites](https://craftpix.net/freebies/free-wraith-tiny-style-2d-sprites/) (idle loop of each of the 3 wraiths) | `ios/PurgeQuest/Assets.xcassets/Monsters` |

**How these were matched to the repo.** The hero packs and the Wraiths by name and by comparing the pictures
with each product image. The staves and shields by art style and one identical shield design, and the owner
confirmed on 13 November 2026 that they are the CraftPix packs.

## itch.io

| Used for | Pack | Author / source | License | Status |
|---|---|---|---|---|
| Forest Spirit pets: Bluebell, Mossy, Ember and Sunny Sprout (`Pet-spirit*`) | Cute Forest Spirit - Sprite Pack (idle loop, 4 of its 7 colors) | Mica, [micaellebritto.itch.io/forest-spirit](https://micaellebritto.itch.io/forest-spirit) | "You may use and modify the assets for personal and commercial projects. You may not edit and resell as another asset pack." No credit is required or requested | OK for a game. The page does not say whether the original files may be re-shared, so ask the author before they go anywhere public |
| Phantom Purge event: Sheet Ghost and Cave Bat pets, banner decor (`Halloween-*`) | Halloween Props & FX, free sampler | LumioLab, <https://lumiolab.itch.io/halloween-props-fx> | Custom, copied in [`licenses/lumiolab-halloween-sampler.txt`](licenses/lumiolab-halloween-sampler.txt). Commercial use and modification are allowed, no attribution is required, no resale as assets, no training of generative models | OK for a game |

## Font

| Used for | Font | Author | License | Status |
|---|---|---|---|---|
| Titles and headings (Regular, SemiBold and Bold, in `ios/PurgeQuest/Assets.xcassets/Cinzel-*.dataset`) | Cinzel | Natanael Gama and The Cinzel Project Authors | SIL Open Font License 1.1, copied in [`licenses/cinzel-OFL.txt`](licenses/cinzel-OFL.txt) | The fonts are used unmodified. The license asks that its notice and text travel with the font: the files carry the copyright line and a license URL, and the Credits screen in Settings shows the full text (the `Cinzel-OFL` data asset, kept identical to `licenses/cinzel-OFL.txt` by `repo_guard.py` check 16) |

## Made for this app

- The 11 store weapons and shields (`ios/PurgeQuest/Art/Gear/store/`) are drawn in code by `tools/modular_assets/store_gear.py`.
- The fallback hero avatar (`MiniAvatar*`) is drawn in SwiftUI.

## Made by the owner, with Grok

- **App icon, PurgeQuest emblem and the six Bestiary family icons** are the owner's own icons, made with Grok
  (xAI), as the owner said on 13 November 2026. The emblem is cut out of
  `docs/design/mockups/splash-light.jpg` and the icons are traced from `docs/design/mockups/bestiary-dark.jpg`;
  the app icon arrived with the Rork-generated project (commit `f0a853d`).
- **Still to check: xAI's terms for Grok output.** xAI's legal page refused an automated fetch, so the terms
  have not been read here. Before release, read them for who owns the output and whether it may be used
  commercially in an app, then record the date and the result on the next line. Copyright protection for
  AI-generated images is limited in some countries (in the US only the human-authored part is protected),
  which affects how far anyone could stop others copying the icons, not the right to use them.

  xAI terms checked: not yet.

## Rules that keep these licenses satisfied

- **Never let the app save, share or export the third-party art.** The CraftPix terms forbid it, which is why
  the Hero Card in Settings is view-only. Check any new feature that turns the art into an image (a share
  sheet, saving to Photos, an export) against these terms first.
- **Never use this art to train, test or improve an AI or machine-learning model.** CraftPix and LumioLab both forbid it.
- **Keep the original archives out of the repo.** Only converted files belong here.
- **Keep the Credits screen in step with this file.** `ThirdPartyCredits.swift` lists the packs on the screen,
  and `repo_guard.py` (16) keeps the Cinzel license text in the app identical to `licenses/cinzel-OFL.txt`.

## How the files were prepared

- **Heroes and gear:** the packs' layered PNG parts and Spriter projects, used by `Services/SpriteEngine.swift`;
  `tools/modular_assets` also cuts them into anatomy and armor layers (`Art/Modular/`) and recolors them in the
  Forge (see `docs/modular/README.md`).
- **Wraiths:** the 12 idle frames of `Wraith_01`, `Wraith_02` and `Wraith_03` (teal, brown, purple),
  trimmed to a shared box, scaled to 160 px tall and joined into one horizontal sheet each.
- **Forest Spirits:** the 8 idle frames per color, trimmed to a shared box and joined into one sheet.
- **Halloween:** the sampler's own sheets, unchanged. `Halloween-cobweb` is in the catalog but not used yet.

`SpriteArt` (`ios/PurgeQuest/Views/Components/SpriteSheetView.swift`) lists every sheet, and
`tools/ci/repo_guard.py` checks each one against its image.

## Not added

- The KayKit Fantasy Weapons Bits (CC0, 3D), Low Poly Fantasy Weapon Asset Pack Lite (3D), and the painted
  weapon Icons and Textures packs were reviewed and left out: the app uses flat 2D sprites.
- CraftPix's Elemental Spirits Chibi Character Sprite Pack is a paid (Premium) download and is not used.
  Premium terms (section 1 of the same license) are stricter: they also say distribution of source files is
  not permitted, so keep it out of a public repo if it is ever used.
