# Screenshot plan

## What to make

iPhone only, portrait. Upload one set at the largest size App Store Connect currently asks for (the 6.9-inch class at the time of writing) and let it scale the rest; confirm the required sizes on the upload page, since Apple changes them.

Six screenshots, in this order. The first two carry the listing: they are all most people see.

| # | Screen | What it has to show | Caption |
|---|---|---|---|
| 1 | Combat card, mid-swipe to the left | A real-looking photo as a monster card with its name and the "why" line | Turn photo cleanup into a dungeon crawl |
| 2 | Room Summary | The list of marked items and the confirm button | Nothing goes until you say so |
| 3 | Dashboard | Storage reclaimed, the daily quests, Enter the Dungeon | See what you have freed |
| 4 | Duplicate group card | Several copies with the suggested keeper starred | Finds the copies. You pick the keeper |
| 5 | Bestiary, one family open | Monsters met, with the signal that summons each | 36 monsters, each a kind of clutter |
| 6 | Hero tab or Forge | The hero with gear equipped | Earn gear by clearing space |

Rules for every shot:

- **Use photographs you own or made for this.** The library on screen appears in the listing. No real people's faces, no screenshots of other apps, nothing personal.
- **Say "moves to Recently Deleted" somewhere in the first two.** Recoverability is the feature that separates this from a delete tool, and it pre-empts the reviewer's first question.
- Do not show Live Activities or the Dynamic Island: the build has none.
- Light or Dark, not a mix. Dark suits the dungeon art; pick one and keep all six in it.
- No device frames are required; if you add them, add them to all six.

## Capturing them

`PurgeQuestUITests/AppearanceTourUITests` already drives the real app through its screens in Light and Dark and saves a PNG of each. CI uploads them as the `ui-snapshots` artifact on every run, which is the quickest way to see the current state of each screen:

- `<mode>-10-library`, `<mode>-12-library-scrolled`: Dashboard (shot 3)
- `<mode>-11-combat`: combat (shot 1)
- `<mode>-2x-…`, `<mode>-3x-…`: the tabs, including Bestiary and Hero (shots 5 and 6)
- `<mode>-23-forge`: the Forge (shot 6)

Those run on a simulator with a nearly empty library, so they are for layout, not for the listing. For the listing:

1. Put the photographs chosen above on a device (or a simulator, via drag and drop into Photos).
2. Run the app from Xcode on the largest iPhone simulator and take each shot with **File > Save Screen** (Cmd-S), which saves at the exact pixel size the store wants.
3. For shot 1, hold the card mid-swipe; for shot 4, the library needs a burst or a few copies of one picture.

The Room Summary and the duplicate group card are not in the automated tour. Adding them to `AppearanceTourUITests` would keep the set reproducible; it has not been done.

## App preview video (optional)

Fifteen to thirty seconds: three swipes, the Room Summary, the confirm, then Photos > Recently Deleted. The last step is the one worth showing.
