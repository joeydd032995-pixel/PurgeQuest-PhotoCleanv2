# The gem economy

Set by the owner on 17 November 2026: **a photo pays 2 gems, a video 3, and every shop price is 2.25 to 2.75 times what it was.** Every other gem amount is sized against those two facts, and each is a constant in one place so it can be retuned.

## Where gems come from

| Source | Amount | Where it lives |
|---|---|---|
| Deleting a photo | 2 | `DiveRules.gemsPerPhoto` |
| Deleting a video | 3 | `DiveRules.gemsPerVideo` |
| A Perfect Room (nothing kept) | 10 (5 photos' worth) | `DiveRules.perfectRoomBonusGems` |
| Each room of a completed dive | 8 (4 photos' worth) | `DiveRules.fullDiveBonusGemsPerRoom` |
| A daily quest | 20 to 100, see below | `QuestCatalog.daily` (`Models/GameContent.swift`) |
| Real-money gem packs | 500, 1,250, 2,000, 4,500, 10,000 | `Services/StoreKitService.swift` |

A deletion's gems are flat: not scaled by file size, the combo or the hero's class. Keeping a photo earns nothing and costs nothing.

## Where gems go

| Sink | Price | Where it lives |
|---|---|---|
| A shop item | base price x 2.5, to the nearest 10 gems | `Models/ShopPricing.swift` |
| The Rally (off while keeping is free) | 250 (base 100 x 2.5) | `DiveRules.rallyCostGems` |

## Quests

A quest pays 1.5 to 3.5 times the gems of the deletions it asks for, the rarer the ask the more, rounded to 5. `EconomyBalanceTests` holds that band.

| Quest | Asks | Its deletions pay | It pays | Was |
|---|---|---|---|---|
| Blur Beast Hunter | 8 photos | 16 | 25 | 60 |
| Duplicate Dragon Slayer | 5 items | 10 | 25 | 80 |
| Video Vampire Purge | 6 videos | 18 | 40 | 100 |
| LongTake Leviathan | 3 videos | 9 | 25 | 140 |
| Dungeon Clear | 25 items | 50 | 75 | 70 |
| Memory Hog Hunter | 2 videos | 6 | 20 | 140 |
| Storage Liberation | 500 MB | about 50 items | 100 | 120 |

Four of the seven are drawn each day. The old rewards (60 to 140) were set when a photo paid about 2.7 gems and a video tens, and would now be worth 30 to 70 photos each. Scaling them up by the 2.5 shop factor instead would make a quest worth 75 to 175 photos and quests the main income, so they went down.

## What it adds up to

| | Gems | In photos |
|---|---|---|
| A full dive of 100 photos | 200, up to 290 with every bonus | 100 |
| The four daily quests, on average | about 175 | about 90 |
| The cheapest paid item (550) | | 275 |
| Arcane Edge (2,250) | | 1,125 |
| Titan Blade (7,500) | | 3,750 |

## The real-money gem packs

Set by the owner on 20 November 2026: five consumable packs (`com.purgequest.gems.500`, `.1250`, `.2000`, `.4500`, `.10000`). The dollar prices in `Configuration.storekit` are **test values** (1.99, 3.99, 5.99, 9.99, 19.99, the same gems-per-dollar curve as before); the real prices are set in App Store Connect, which this repository cannot do. The products are not live yet (the launch checklist's App Store Connect step is still open), so renaming them cost nothing. What a pack buys: 500 gems is just short of the cheapest paid item (550), 2,000 buys one Gem Hammer, and 10,000 buys the Titan Blade (7,500) with change.

## Not changed, and why
- **The hero classes' gem perks** (Voidstalker and Water Shaman +15%, Earth Shaman +10%). On a flat 2 or 3 gems a per-deletion bonus rounds away to nothing, so they do nothing today.
