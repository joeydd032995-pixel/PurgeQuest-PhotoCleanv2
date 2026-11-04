# Third-party art credits

Art in the app that was not drawn for it. Only the converted files the app uses are in this repo
(sprite sheets in `ios/PurgeQuest/Assets.xcassets/{Monsters,Pets,Halloween}`), never the original
packs. The licenses below allow use inside a game and forbid redistributing the assets as assets, so
keep the original archives out of the repo.

| Used for | Pack | Author / source | License | Status |
|---|---|---|---|---|
| Mist, Tatter and Void Wraith monsters (`Monster-*Wraith`) | Free Wraith Tiny Style 2D Sprites (idle loop of each of the 3 wraiths) | Craftpix, item 563568 | [Craftpix file license](https://craftpix.net/file-licenses/) (the archive contains only this link) | Verify the terms on the Craftpix page before release |
| Forest Spirit pets: Bluebell, Mossy, Ember and Sunny Sprout (`Pet-spirit*`) | Forest Spirit Sprites (idle loop, 4 colors) | Not stated in the archive | The archive has no license or readme | **Unconfirmed.** Find the author and license before release |
| Phantom Purge event: Sheet Ghost and Cave Bat pets, banner decor (`Halloween-*`) | Halloween Props & FX, free sampler | LumioLab, <https://lumiolab.itch.io/halloween-props-fx> | Custom, copied in [`licenses/lumiolab-halloween-sampler.txt`](licenses/lumiolab-halloween-sampler.txt). Commercial use and modification are allowed, no attribution is required, no resale as assets, no training of generative models | OK for a game |

## How the files were prepared

- **Wraiths:** the 12 idle frames of `Wraith_01`, `Wraith_02` and `Wraith_03` (teal, brown, purple),
  trimmed to a shared box, scaled to 160 px tall and joined into one horizontal sheet each.
- **Forest Spirits:** the 8 idle frames per color, trimmed to a shared box and joined into one sheet.
- **Halloween:** the sampler's own sheets, unchanged. `Halloween-cobweb` is in the catalog but not used yet.

`SpriteArt` (`ios/PurgeQuest/Views/Components/SpriteSheetView.swift`) lists every sheet, and
`tools/ci/repo_guard.py` checks each one against its image.

## Not added

The KayKit Fantasy Weapons Bits (CC0, 3D), Low Poly Fantasy Weapon Asset Pack Lite (3D), and the
painted weapon Icons and Textures packs were reviewed and left out: the app uses flat 2D sprites.
