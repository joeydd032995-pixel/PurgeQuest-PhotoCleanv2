# PurgeQuest UI assessment and redesign

Reviewed 14 November 2026 against `main` at `57fb954`. Two lenses: **structure and first-time clarity**, and **aesthetic quality**. The proposed visual system is a browsable reference: [PurgeQuest Design System](https://claude.ai/artifact/XzoCfygVeRtn6MsYKVWGWx) (tokens in both themes, ten components with live previews, three screen compositions). It is private to the account that made it; the same rules are written out in sections 7 to 10 below.

## 0. About this assessment

**Evidence.** 92 simulator screenshots from CI (run 43598805569, artifact `ui-snapshots`: Light and Dark, Classic and Verdigris; it expires 28 November 2026, and the "UI snapshots" workflow regenerates it). Source reading of onboarding, Library, combat, Room Summary, Hero, Armory, Settings, Trophies and the tokens. Contrast and colour distance computed from the shipped tokens (`ThemePalette.swift`). Contrast measured from rendered pixels. Usage counts by grep (Appendix A, with the commands).

**Limits, stated plainly.**

1. **This is an expert review, not research.** There are no participants and no analytics (by design). Severities are judgment. Every S0 finding is written so five real first-time users can confirm or refute it (section 12).
2. The screenshots come from a simulator with six synthetic photos. Nothing here says how the app behaves on a real library, with iCloud originals, or at speed.
3. Not rendered, so judged from code or not at all: the system "More" list that holds Trophies and Settings, the duplicate-group card, Room Summary, Dungeon Complete and Defeat, Dynamic Type at large sizes, VoiceOver, Reduce Motion.
4. Tooling notes. The `impeccable` skill's body is empty in this install (it reads `...` after its heading), so only its stated aim, a distinct point of view instead of generic defaults, was applied. `ui-styling` targets shadcn and Tailwind, which do not apply to SwiftUI; its token discipline is used and a CSS mirror is given in section 7.9 for the privacy and support pages that launch needs. `theme-factory`'s "create your own theme" step produced the named theme in section 7.

**Reading the tables.** Severity: **S0** blocks the user's job or breaks trust; **S1** major friction or a clear quality failure; **S2** moderate; **S3** polish. Confidence: **V** verified in source or screenshot; **R** reasoned, confirm on a device.

## 1. The diagnosis in one page

**The UI is organised around what its builder knows.** The owner is the author and the expert user, so the things the owner uses (Dates, Focused Dive, Hunt Chosen, the Forge, the palette switch, a three-way storage ledger) sit on the surface. A first-time user needs the opposite: one promise, one action, one reason to trust it. Nothing here is badly built; it is built for the wrong reader.

Three root causes sit under the 29 findings:

1. **The loop works against the job.** A cleanup app is judged by how safely it helps you decide. Here, keeping a photo costs HP and ends the game after 6 to 13 keeps (S-01), the first card ships behind nine taps and three character-creation screens (S-03), and a denied permission is a dead end and, later, reads as "all clear" (S-02).
2. **Everything is a card of equal weight.** The Library home stacks nine blocks in five visual treatments (S-05) and spends brass, the brand's one luxury signal, 154 times on eight meanings (A-01). When everything glows, nothing does.
3. **The design system exists on paper.** `DESIGN_SYSTEM.md` has ten good rules; the code has ten corner radii where three are documented, 45 hand-rolled panels beside 16 uses of the shared one, and contrast failures the unit tests permit (A-02, A-07).

**What is already good** (and must survive): the brass plate is the clearest hierarchy device in the app; the swipe stamps are the best micro-interaction; the Bestiary is the one screen that looks art-directed; the storage ledger's honesty and "Old photos are memories, not junk" are the right voice; the CI screenshot tour is a real design-review loop. Section 5.4 lists them.

### Decisions only the owner can make

| # | Decision | Recommendation | If you disagree |
|---|---|---|---|
| D1 | What happens when you keep a photo (S-01) | Keeping is free. Remove spare damage, defeat and the 100-gem Rally from 1.0 (hide behind a flag, do not delete code). | Keep HP but drain it only by time pressure, never by a decision; or keep it and say so on onboarding page 1 (not recommended) |
| D2 | Default look | **Verdigris Vault** (Dark) and **Parchment** (Light) become the only themes. Retire the Classic charcoal and the Palette switch at the top of Settings. | Keep Classic as a second option under Appearance, lower in Settings |
| D3 | Tab structure | Five tabs, no More: Dungeon, Hero, Codex (Bestiary + Trophies), Armory, Settings. | Keep Bestiary and Trophies separate and fold Trophies under Hero |
| D4 | Gem colour | Gems are **ice** (cool diamond). Green is reserved for keeping and measured results. | Keep emerald gems and make Keep neutral ivory with a shield |
| D5 | Glitchborn hue | Orchid, a new hue. It breaks DESIGN_SYSTEM.md rule 9 ("no purple"), so amend that rule. | A neutral static grey |
| D6 | App icon | Redraw from the brass emblem on verdigris-black so icon, splash and UI are one identity. | Keep the lava painting and bring ember into the UI as the destructive hue |

## 2. The first-time user

**Job.** *When my iPhone says Storage Almost Full, I want to remove the photos and videos I will not miss, without risking ones I would regret, so the warnings stop.* The RPG layer has a second job: make a chore bearable enough to repeat. It must serve the first job, never compete with it.

**Proxy persona (an assumption, not data).** Found the app from App Store screenshots promising cleanup plus a game. An iPhone with 10,000 to 30,000 items and a storage warning. Wary of two things: granting photo access and deleting something irreplaceable. Plays casually; gives an app about three minutes before deciding it is worth keeping.

**The owner as primary user.** Where an owner preference conflicts with a first-timer's need, this review resolves for the first-timer and moves the owner's tools one level deeper. It never removes them.

**First-session journey, as built.**

| Stage | What the user does | Expected feeling | Evidence |
|---|---|---|---|
| Launch | Splash, 0.45 s | Reassured by a premium emblem; the tagline ("Clean your Digital Dungeon and Tidy Your Digital Keep!") is muddled | `tour-dark-00-splash.png` |
| Onboarding 1 | Reads three grey lines under a large emblem | Mildly curious; the promise is the weakest text on the screen | `tour-dark-01-onboarding.png` |
| Onboarding 2 | Allows photo access | Anxious; the copy is good, the denied path is a dead end (S-02) | `OnboardingView.swift:81-117` |
| Onboarding 3 to 5 | Picks a race (8), a class (17), a name, a paint, a skin, a hair and a dye | Impatient; none of this has shown value yet | `OnboardingView.swift:139-313` |
| Onboarding 6 | Watches a looping demo card | Finally understands the verb | `:407-436` |
| Library | Meets a nine-block stack | Unsure what is the next action beyond the brass plate | `tour-dark-10-library.png` |
| First card | Decodes 16 elements | Overloaded; sees "+78 XP" beside "Review carefully" | `tour-dark-11-combat.png` |
| Keeping photos | Hero takes damage, screen shakes | Confused and punished (S-01) | `CombatViewModel.swift:409-425` |
| Room Summary | Scrolls to find the commit, taps three confirmations | Cautious, slightly tired | `RoomSummaryView.swift:167-216` |
| Result | "Storage freed" here, "Not yet verified" on the dashboard | Distrust (S-04) | `CombatView.swift:256`, `DashboardView.swift:188` |

## 3. Information architecture today

```
App
├─ Splash (auto)
├─ Onboarding: 6 swipeable pages, no Skip
│    Intro → Permission (disables the button; the swipe is not gated, to verify) → Race (8) → Class (17) + Name → Look (paint, skin, hair, dye) → Swipe tutorial
└─ Main: TabView with 6 tabs; iOS shows 5 and folds the rest under "More"
     ├─ Library ──► Combat (pushed; tab bar stays) ──► Room Summary ──► custom alert ──► system delete dialog ──► Dungeon Complete | Salvage (defeat, Rally 100 gems)
     │     ├ Focused Dive (menu; a tap starts a dive)   ├ Hunt Chosen (picker; picking starts a dive)   └ Dates (sheet: All | Only | Exclude, start, end, quick picks)
     ├─ Hero ──► Forge (full-screen cover) · gear rows jump to the Armory tab
     ├─ Bestiary ──► Family ──► Monster
     ├─ Armory (gem packs, cosmetics, Restore Purchases) · tapping a tile equips it
     └─ More ──► Trophies · Settings (Appearance, Cleanup, Lifetime Stats, Recently Deleted, Privacy, About/Credits, Reset)
```

Facts that matter: six destinations; three of them (Bestiary 0/36, Trophies 0/11, Hero gear "Nothing equipped") open as walls of zeros on day one; Hero data repeats in the Library strip and the Hero tab; lifetime stats repeat in the Hero tab and Settings; equipping is split between the Hero and Armory tabs; deleting takes three confirmations after the decisions.

## 4. Cognitive walkthrough, first session

Task: *free up some space by deleting photos I do not need.* For each step: will the user try the right action, notice it, connect it to their goal, and see progress? **Pass**, **Risk** or **Fail**.

| # | Step | Verdict | Why |
|---|---|---|---|
| 1 | Open the app | Pass | Premium splash; the tagline is noise (A-05) |
| 2 | Read the promise (onboarding 1) | Risk | The promise ("reclaim your storage") is grey 17 pt body text under the loudest element on the screen; no Skip |
| 3 | Grant photo access | **Fail** if denied | Chip says "Open Settings", no control does that; Continue stays disabled; two gold buttons on the page; the page can be swiped past (R); if the user gets in anyway, a dive reports "All clear" |
| 4 | Choose a race | Risk | Eight options, no consequence explained, marketing subtitle ("Every paint job recolorable") |
| 5 | Choose a class, name the hero | **Fail** | 17 rows, unexplained perks, an unlabeled name field mid-list; decision paralysis before any value |
| 6 | Shape the look | Risk | Four swatch rows of pure cosmetics |
| 7 | Learn to swipe | Pass with friction | Right content, wrong moment, passive demo, last |
| 8 | Library: what now? | Risk | The brass plate answers it, 60% down; Focused Dive and Hunt Chosen are unexplained and start a dive on tap |
| 9 | Wait for the scan | Risk (R) | "Summoning monsters from your library…" with no progress or duration |
| 10 | First card | Risk | 16 elements; rewards next to a safeguard; the tab bar still there |
| 11 | Decide on 20 cards | **Fail** | Keeping costs HP from a 100-point pool shared by the whole dive, resets combo, shakes the screen; 13 keeps end the run |
| 12 | Room Summary and commit | Risk | Commit is about 1.3 screens down; three confirmations; button does not say how many |
| 13 | See the result | **Fail** | "Storage freed 48 MB" contradicts "Actually reclaimed: Not yet verified" |

## 5. Findings

### 5.1 Structure and first-time clarity

| ID | Sev | Conf | Finding | Evidence |
|---|---|---|---|---|
| **S-01** | S0 | V | **Keeping a photo is punished; deleting is rewarded.** Sparing resets the combo, breaks "Perfect Room", shakes the screen and costs 8 to 18 HP (by monster type). HP is **one 100-point pool for the whole dive**, up to five rooms and 100 items: it resets only at dive start, "Continue Deeper" and Rally. At the default 8 damage, keeping 13 cards (13% of a dive) ends the run. The room's marked deletions are then "released unharmed", the dive bonuses are lost, and a "Salvage" screen offers a 100-gem Rally (gems are sold). A careful user loses their work for being careful. It also contradicts the app's own voice ("Old photos are memories, not junk"). | `CombatViewModel.swift:409-425,240,528,756`, `MonsterType.swift:259`, `CombatViewModel.swift:118`, `CombatView.swift:200,330-354` |
| **S-02** | S0 | V | **Denied access is a dead end, and later reads as "all clear".** After "Don't Allow" the chip says "Access denied. Open Settings to enable" but nothing opens Settings: the button only re-reads status, Continue stays disabled, and the only Settings deep link in the app lives in the Library picker alert. Nothing re-checks when the app returns to the foreground. Worse, if access is denied or later revoked, the standard dive never checks authorization: the fetch returns nothing, the Library says "All reviewed" and the dive ends on "All clear. Your library has nothing to review right now." (`PhotoLibraryError.denied` exists and is never thrown on this path.) Only the hand-picked hunt reports an access problem, with no Open Settings button. The pager can also be swiped past the gate (R). | `OnboardingView.swift:100-114,461-463`, `AppState.swift:66-74`, `CombatViewModel.swift:173-184`, `DashboardView.swift:87,126-128`, `CombatView.swift:91-101` |
| **S-03** | S0 | V | **Time to value is 9 taps, 7 screens and three decision screens.** Splash, six onboarding pages, then the Library, then a tap, before the first card. The verb is taught last. 8 races × 17 classes × paints, skins, hair and dyes come before any photo is seen. | `OnboardingView.swift:44-51,139-313,407-436` |
| **S-04** | S1 | V | **Storage language contradicts itself.** The Library separates To review, Pending and Reclaimed (good) while the room result says "Storage freed", Hero and Settings say "Total freed", onboarding says "reclaim your storage". Bytes in Recently Deleted are not free. "Not yet verified" is the largest type in its row, so absence reads as an error. | `CombatView.swift:256,322`, `HeroTabView.swift:173`, `SettingsView.swift:94`, `DashboardView.swift:188-191` |
| **S-05** | S1 | V | **The Library home is nine blocks in five treatments.** The ledger alone is 27% of the viewport and sits above the action; the brass plate's top edge is at 60%. Focused Dive, Hunt Chosen and Dates are power tools at the same level as the primary action. The Next dive banner describes the action but sits below it and does nothing. Quests are four identical cards below the fold. The hero card duplicates the Hero tab. | `DashboardView.swift:41-61`, `tour-dark-10-library.png` |
| **S-06** | S1 | V | **The first card carries 16 elements and covers a third of the photo.** Banner, exit, HP bar, room, remaining, theme (again), combo, family chip, ELITE, quote, reason, Review carefully, size and age, XP and gems, two buttons. The frosted strip spans 36% of the card's height. The theme shows twice and truncates ("Wild Gall…"); the HUD row wraps with orphan bullets; the exit button is 36 pt; the tab bar stays visible during a focused mode. | `CombatView.swift:119-137,209-236`, `CombatHUD.swift:24-56`, `SwipeMediaCard.swift` `bottomMetaBar` |
| **S-07** | S1 | V | **Room Summary buries the commit.** On a 20-item room the confirm button is about 1.3 screens down (computed from the three-column grid). "Room Cleared" is shown before, and even without, a purge. Three confirmations follow the decisions: the summary, an in-app alert, the system dialog. The button says "Confirm Purge", not how many or where. Per-tile reward text is fixed 9 pt. | `RoomSummaryView.swift:21,75-95,167-216,273` |
| **S-08** | S1 | V | **No undo, and Delete outweighs Keep.** There is no way to reverse a decision until the room summary. Delete is a saturated fill; Spare is a grey secondary button. Swipe discoverability depends on a passive demo shown six screens earlier. | `CombatView.swift:181-201`, no `undo` in combat sources |
| S-09 | S2 | V | **Jargon without a gloss.** Dive, Hunt Chosen, Focused Dive, Elite, Shade, Leviathan, "Gear tier", "Dashboard Strip", "Palette", "Identified opportunity". Quests are the first place the monster vocabulary appears and they cannot be decoded ("Defeat 3 Leviathans over 2 minutes"). | `tour-dark-12-library-scrolled.png`, `HeroForgeView.swift` |
| S-10 | S2 | V | **IA: six tabs, a system "More", duplicated data.** Trophies and Settings are two taps away on a system-styled list. Three tabs open empty. Hero summary and lifetime stats repeat. Equipping spans two tabs. "Restore" sits top-right of the Armory. The tab "Library" suggests browsing photos, but it is the game lobby. | `ContentView.swift:55-82`, `HeroTabView.swift:26-33`, `SettingsView.swift:91-98` |
| S-11 | S2 | V | **Empty states give no next step.** "Nothing equipped" × 5 while free gear waits in the Armory; 0/36 and 0/11 with no invitation; quests "Generating today's quests." | `tour-dark-20-hero.png`, `-21-bestiary`, `-30-trophies` |
| S-12 | S2 | V | **Settings is ordered by the builder.** Appearance and Palette first, Lifetime Stats inside Settings, the Recently Deleted log and privacy buried. "Longest streak 1 days". | `SettingsView.swift:51-139`, `:96` |
| S-13 | S2 | V | **Armory state signals are ambiguous.** "+150 gems" under a price reads as a gain; it is a shortfall (VoiceOver says "You need 150 more gems"). A gold outline means "next goal" with no label, beside an emerald outline for "equipped". Locked tiles dim to 50%, which is the item being evaluated. | `ShopView.swift:497,583-587` |
| S-14 | S3 | V | **Power tools are exposed.** The Dates sheet (All, Only, Exclude, start, end, quick picks) is on the home screen. The Focus menu has no Duplicates, the app's headline monster. | `DashboardView.swift:340-363,400-463`, `DatesSheet.swift` |
| S-15 | S3 | V | **Onboarding small defects.** Marketing copy instead of decision help; the name field has no label; two brass plates on the permission page; the demo's `while true` never cancels. | `OnboardingView.swift:100-114,145,215,523` |
| S-16 | S3 | R | **Scan wait has no progress.** | `CombatView.swift:81-87` |

### 5.2 Aesthetic quality

| ID | Sev | Conf | Finding | Evidence |
|---|---|---|---|---|
| **A-01** | S1 | V | **Brass is spent on everything.** 110 uses of the amber accent in 27 files and 44 of the plate tokens, for: primary action, level, XP, rewards, selection (filter chips, Forge chips, toggles, the tab tint), secondary buttons ("Forge Hero", "Armory", "Tap to equip"), warnings ("Review carefully"), badges, the first Bestiary tile, the event banner. The Forge gives the plate to a selected tab chip while "Save Hero" is plain grey, against the system's own rule 2. | Appendix A; `tour-dark-23-forge.png` |
| **A-02** | S1 | V | **Measured contrast failures.** Combat meta in Light: size text **2.20:1**, XP **2.38:1** against the rendered panel (Light accents drawn on an always-dark glass). Dark: size 3.79:1. The tertiary text tier is **2.83:1** on Dark wells and below 4.5:1 in 11 of its 12 theme-and-ground combinations. Role text on its own 16% tint is 2.89:1 for crimson, and 3.68 to 4.00:1 for four of the six Bestiary "found" pills. The repo's tests accept 3:1 for these. | `audit_colors.py` run; pixel samples of `tour-*-11-combat.png`; `ThemePaletteTests.swift:52-57,82-83` |
| **A-03** | S1 | V | **Colour roles collide.** Emerald means gems, keeping, success, "reclaimed" and the file size. Crimson means delete, HP, the streak flame and (as coral and rose) two monster families: coral, rose and crimson are **ΔE 10.1 to 10.3 apart in Dark; coral and crimson are ΔE 3.8 in Light**, effectively one colour. The Clutter Undead hue is ΔE 5.6 from brass, so its tile looks selected. Jade and emerald are ΔE 11 (Dark). | `ThemePalette.swift:147-160`, `tour-dark-21-bestiary.png` |
| **A-04** | S1 | V | **Seven rendering dialects.** A glass tab bar, a bevelled brass plate, flat hairline panels, frosted dark overlays on photos, pixel-art event decor, chibi sprites in dark stage frames, default system controls and SF Symbols. Only the splash and the Bestiary look art-directed. | all tour screens |
| A-05 | S2 | V | **No type scale.** Cinzel appears 39 times against 234 system text styles, including at 12 pt label sizes where its wide capitals lose legibility, while Trophies, Settings and the race names are system type. 28 fixed-size fonts, 12 of them 8 to 10 pt. Casing and spelling vary ("LIBRARY", "Trophies"; "colours" beside "colors"; a Title-Case tagline). | `DungeonFont.swift`, Appendix A |
| A-06 | S2 | V | **Depth does not land.** In Light the card is only 1.06:1 (ΔL\* 2) lighter than the canvas, so cards barely exist. In Dark a 28% black shadow on the canvas reads 1.04:1, so the shadow half of the system is invisible; depth rests on a 1.47:1 hairline. | `DungeonSurface.swift:31-48` |
| A-07 | S2 | V | **Token discipline.** 10 corner radii (documented: 3; the dominant one, 10, is not a token); 45 hand-rolled panel fills vs 16 `DungeonPanelBackground`; 26 distinct tint opacities; 48% of padding and 53% of stack-spacing literals off a 4 pt grid; 8 spring curves; 84 buttons, 11 of them using the one shared style; raw white 32×, black 15×. | Appendix A |
| A-08 | S2 | V | **The hero is not the subject.** The Hero tab sprite fills 19% of its own card; the Library strip hero is 84 pt; Armory and Forge previews are small. This is the system's own rule 1. | `tour-dark-20-hero.png`, `DESIGN_SYSTEM.md` rule 1 |
| A-09 | S2 | V | **Polish defects, together "unfinished".** Scrolled content collides with the status bar; list text bleeds through the tab bar; lists hard-clip under the onboarding and Forge footers; "Wild Gall…" truncates; Armory tile tops differ by about 8 pt; Trophies has two titles and a dead gap of about 65 pt; default segmented controls and toggles; the event banner title wraps beside pixel art. | `tour-dark-12`, `-22`, `-30`, `regression-1` |
| A-10 | S2 | V | **The icon is not the product.** A hyper-detailed lava and ember painting (oranges, red, a green gem) heads a restrained charcoal-and-gold app with a brass shield emblem. The detail will not survive 60 pt. | `AppIcon.appiconset/icon.png` |
| A-11 | S3 | V | **Light mode loses identity.** Parchment cards on parchment; the plate is the only brand element. | `tour-light-10-library.png` |
| A-12 | S3 | V | **Motion has no identity and breaks its own rule.** Springs only, in 8 variants; the rules say "no loops" yet onboarding's demo loops forever and `CelebrationFX` repeats. The swipe stamps are the exemplar. | `OnboardingView.swift:523`, `CelebrationFX.swift:173` |
| A-13 | S3 | V | **Iconography is generic.** SF Symbols everywhere the Bestiary's bespoke line art would fit; the flame is both the streak and the Golden Sparks effect. | `tour-dark-12`, `-22` |

### 5.3 Aesthetic scorecard (1 to 10; the `aesthetic` skill's pass bar is 7)

| Surface | Score | Note |
|---|---|---|
| Splash and emblem | 8 | Confident; fix the tagline |
| Bestiary | 7 | Art-directed; two hues collide |
| Combat card (photo, stamps) | 6 | Physics are good; overlay and HUD are not |
| Onboarding | 5 | Clean, but cosmetic-heavy and clipped |
| Library | 5 | Competent card stack, no focal point |
| Hero | 5 | Small figure, big frame |
| Forge, Armory | 4.5 | Default controls, small previews, plate misuse |
| Room Summary | 4 | Data dump; acknowledged in the design doc |
| Trophies, Settings | 3.5 | System titles, default lists, double headers |
| **Overall** | **5** | Target 8 |

### 5.4 What to keep

1. The brass plate (`GoldButtonStyle`) as the single primary control.
2. The swipe stamps and card physics (`SwipeMediaCard` drag, rotation, stamp scaling).
3. The Bestiary tile art direction and the owner's line icons.
4. The Cinzel wordmark, the emblem and the splash composition.
5. The honest storage vocabulary, and copy such as "Old photos are memories, not junk" (`FamilyDetailView.swift:62`).
6. The accessibility groundwork: `accessibilityAdjustableAction` on the card, Reduce Motion handling, a unit-tested palette.
7. The CI screenshot tour. Extend it; do not replace it.

## 6. Redesign principles

### Structure

1. **One job per screen, one next action.** Each screen answers "what do I do next?" with exactly one strongest control; everything else recedes.
2. **Value before identity.** The first card within three taps and about 45 seconds. Character creation is a reward after the first room, not a gate. Teach on the real card.
3. **Safe by default, and visibly so.** Keeping is free. Every destructive step names its count and destination. Decisions can be undone until the room commits. A reward never shares a surface with a safeguard.
4. **Disclose progressively.** Day-one UI shows only what a first-timer can use. Power tools sit one tap deeper, in one sheet. Progress screens explain themselves when they are empty.
5. **Plain words first, lore second; one measurement vocabulary.** Every game term carries a plain gloss at first sight. "Freed" only ever means measured.

### Aesthetic

1. **Calm chrome, dramatic moments.** Utility surfaces are quiet and exact. Brass glow, Cinzel display, particles and spring motion are rationed to earned moments: Room Cleared, level-up, a discovery, an unlock.
2. **Colour means something; illustration means someone.** Four role colours (brass, ember, patina, ice) carry meaning everywhere. Monsters are identified by line art, and family hues appear only in the Bestiary.
3. **Stone, brass, ink: one material language.** Matte stone panels lit from above, brass inlay for the one primary control, glass only over photographs and in system bars.
4. **The photograph is the subject of the card; the hero is the subject of the stage.** At least 72% unobstructed photo; a hero at 160 pt or taller.
5. **A polish floor is a feature.** No truncation, no clipped lists, no text below 12 pt, 4.5:1 for every text role, a defined scale used 100% of the time and enforced by tests, not memory.

## 7. Visual direction and system decisions

### 7.1 What "elevated" means here

A product that is *calm before it is clever*: one thing glows per screen and it is the thing to press; type has architecture (three inscription roles in Cinzel, everything else quiet SF); surfaces have a lit edge and a clear step instead of a border doing all the work; the user's photo is the biggest thing on the card; the dungeon appears where it pays (a level-up, a discovery) and recedes where it would slow a decision. References for the feel, not to copy: the restraint of Things 3 and Flighty, the brass-on-dark discipline of Hades' menus, Apple Wallet's tactile cards. These are described, not measured, as no reference screenshots were captured here.

### 7.2 The theme: Verdigris Vault and Parchment

A deep verdigris-black ground (oxidized copper), aged brass, ivory ink and ember for the one thing that destroys. Light is parchment with brown-warm shadows. Fonts: **Cinzel** (display, title, plate only; already bundled under the OFL) and **SF Pro** (everything else; Dynamic Type). The original "Verdigris Deep" palette already exists in the repo; this promotes it and fixes what it lacked: separation, role discipline and contrast.

### 7.3 Colour tokens (all text pairs verified; values in the design-system `tokens.json`)

**Neutrals and text**

| Token | Dark | Light | Rule |
|---|---|---|---|
| `canvas` | `#0D1310` | `#E9E3D2` | Screen. Darker than the card in Light |
| `surface` | `#17221C` | `#F9F6EC` | Cards, grouped lists |
| `raised` | `#213128` | `#DDD6C2` | Wells and controls inside a surface |
| `overlay` | `#2B3F34` | `#FDFBF5` | Sheets, menus, the pinned commit bar |
| `hairline` | `#38503F` | `#C9BFA5` | 1 pt borders; 1.86:1 / 1.69:1 on surface (was 1.47:1 / 1.42:1) |
| `text` | `#F4F0E4` | `#1B1A15` | 9.9:1 / 12.0:1 or better on all four grounds |
| `text-2` | `#C2CABE` | `#4F4C42` | 6.7:1 / 5.9:1 or better |
| `text-3` | `#9CAA9F` | `#5E5A47` | Meta. 4.65:1 / 4.78:1 or better. **No dimmer tier** |

**Roles** (as text on the worst of the four grounds; each also on its own 16% tint)

| Token | Dark | Light | Means | Text / on tint (Dark, Light) |
|---|---|---|---|---|
| `brass` | `#E6B84A` | `#7A5508` | Reward, focus, selected outline. Plate only for the one primary control | 6.08 / 4.62, tint 6.29 / 4.92 |
| `ember` | `#F28F7A` | `#A2392A` | Destruction and loss | 4.82 / 4.59, tint 5.30 / 4.82 |
| `patina` | `#5ED0A8` | `#10634E` | Keep, success, measured results | 5.94 / 4.96, tint 6.14 / 5.22 |
| `ice` | `#86BEE0` | `#275F83` | Information, pending, gems | 5.61 / 4.74, tint 5.87 / 5.03 |
| `ember-fill` + `on-ember` | `#B8473A` + `#FFF6EE` | `#A2392A` + `#FFF6EE` | Delete and the commit button | 4.92 / 6.23 |
| `plate-1…5`, `plate-rim`, `plate-bevel`, `on-brass` | unchanged from today | same | The brass plate | ink 12.7:1 to 5.8:1 |

**Glass over photographs** (theme-invariant, fixes A-02): `glass` `rgba(8,12,10,0.82)` with a 20 pt blur; `on-glass` `#F6F4EC`, `on-glass-2` `#D2D6CC`, and `brass`, `patina`, `ice`, `ember` `-on-glass` (the Dark role values). Worst case, over a white photo: 10.8, 8.1, 6.4, 6.3, 5.9, 5.1 : 1. Today's Light meta text measures 2.2 to 2.4:1.

**Monster families** (Bestiary only, plus a 6 pt dot): `family-undead` `#CFC8B2`/`#6A5C3A`, `-relic` `#9CC97F`/`#3D652D`, `-behemoth` `#9AA6E8`/`#4A55A8`, `-dragon` `#E8806A`/`#96422D`, `-phantom` `#6CC4D6`/`#1C6575`, `-glitch` `#D08AD4`/`#85418E`. Pairwise ΔE2000 at least 17.9 (Dark) and 17.2 (Light), against 10.1 and 3.8 today. Never on combat chips or beside Keep and Delete.

**Also:** four `*-tint` tokens replace 26 ad hoc opacities; `scrim` for dimming; `focus` is a 2 pt `brass` ring.

### 7.4 Type scale

| Style | Face | Size / line | Weight | Use |
|---|---|---|---|---|
| `display` | Cinzel | 34 / 40 | 700 | Screen titles and moment headlines. One per screen |
| `title` | Cinzel | 22 / 28 | 600 | Section titles, monster names, sheets |
| `plate` | Cinzel | 17 / 22 | 700, +0.4 | The brass plate label only |
| `headline` | SF Pro | 17 / 22 | 600 | Row titles |
| `body` | SF Pro | 17 / 22 | 400 | Running text |
| `subhead` | SF Pro | 15 / 20 | 400 | Supporting lines |
| `meta` | SF Pro | 13 / 18 | 500 | Sizes, ages, helper text |
| `eyebrow` | SF Pro | 12 / 16 | 600, +1.0, caps | Labels. Replaces small Cinzel caps |
| `figure-l / m / s` | SF Pro, tabular | 34 / 22 / 15 | 700 / 600 / 600 | Numbers. The figure is always bigger than its label |

All styles scale with Dynamic Type (`Font.custom(_, relativeTo:)` for Cinzel). No `.system(size:)` below 12 pt, and none outside icon glyphs. Sentence case; US spelling; pluralized counts.

### 7.5 Spacing, radius, size

`space-1…12` = 4, 8, 12, 16, 20, 24, 32, 48 pt. Gutter and card padding 16; gap between cards 16; between sections 24. `radius-s/m/l/pill` = 8, 12, 20, capsule, concentric when nested. `tap-min` 44. The 10 pt radius used 69 times maps to 12; the 9 and 14 pt cases fold into 8 or 12.

### 7.6 Elevation

Four steps, not shadows: `canvas`, `surface` (`elev-1`), `raised`, `overlay` (`elev-3` over `scrim`). In Dark, depth comes from the lit top edge (a 6% white inner line) and the lighter surface, because a drop shadow reads only 1.04:1 on the Dark canvas. In Light, shadows are brown-warm and the canvas is darker than the card (card-to-canvas 1.19:1, ΔL\* 6.6, was 1.06:1, ΔL\* 2). `glow-brass` is allowed once per screen.

### 7.7 Motion

Press 90 ms; state change 180 ms; screen transition 280 ms; a reward moment 600 to 900 ms, once. Value changes spring (response 0.45, damping 0.82), a pop is (0.35, 0.70), entering elements ease out. Two springs replace eight. Nothing loops except a spinner. Reduce Motion cross-fades in 180 ms and keeps the information. Choreography for **Room Cleared**: scrim 0.2 s, title rises 0.28 s, ledger rows count up 40 ms apart, the plate glows once.

### 7.8 Icons and illustration

SF Symbols for utility actions, regular weight, one weight per screen. The six Bestiary line icons for monsters, quests, dive themes and empty states wherever an SF Symbol would be generic. A flame is the streak and nothing else; a diamond is the gem and nothing else.

### 7.9 Migration map and web mirror

| Today | Becomes |
|---|---|
| `dungeonVoid`, `dungeonStone`, `dungeonStoneLight`, `dungeonAsh` | `canvas`, `surface`, `raised`, `hairline` |
| `textPrimary`, `textSecondary`, `textTertiary` | `text`, `text-2`, `text-3` |
| `questAmber` (+ `.opacity`) | `brass`, `brass-tint` |
| `combatCrimson`, `combatCrimsonDeep` | `ember` (text), `ember-fill` (fills) |
| `gemEmerald` | `patina` for keep, success, reclaimed; `ice` for gems |
| `xpViolet` (it is jade), `videoSapphire` | `patina`, `ice` |
| `behemothIndigo`, `dragonCoral`, `glitchRose` | `family-behemoth`, `family-dragon`, `family-glitch` |
| `goldInk`, `goldFill`, `goldRim`, `goldBevel`, `goldPlate` | `on-brass`, `plate-3`, `plate-rim`, `plate-bevel`, `plate-1…5` |
| `onAccent` | `on-ember` or `on-brass`, by context |

Keep the old names as deprecated forwarding aliases for one release; migrate screen by screen.

**Web mirror** for the privacy and support pages launch needs (Tailwind v4 `@theme`):

```css
@theme {
  --color-canvas: #0d1310; --color-surface: #17221c; --color-raised: #213128; --color-hairline: #38503f;
  --color-text: #f4f0e4; --color-text-2: #c2cabe; --color-text-3: #9caa9f;
  --color-brass: #e6b84a; --color-ember: #f28f7a; --color-patina: #5ed0a8; --color-ice: #86bee0;
  --font-display: "Cinzel", Georgia, serif; --font-sans: ui-sans-serif, system-ui, sans-serif;
  --radius-s: 8px; --radius-m: 12px; --radius-l: 20px;
}
/* light theme: redefine under [data-theme="light"] with the Parchment column of 7.3 */
```

### 7.10 What the change fixes, measured

| Check | Today | Proposed |
|---|---|---|
| Meta text, worst ground | 2.83:1 Dark, 3.85:1 Light | 4.65:1, 4.78:1 |
| Combat size and XP text in Light | 2.20:1, 2.38:1 | 6.4:1 or better over a white photo |
| Role text, worst ground | crimson 3.43, emerald 4.40 (Dark) | 4.82 (Dark), 4.59 (Light) or better |
| Role text on its own tint | 2.89 to 4.00 in Dark (six accents) | 5.30 or better Dark, 4.72 Light |
| Reds that are "one colour" | ΔE 10.1 (Dark); 3.8 (Light) | one destructive role; families 17.9 / 17.2 apart |
| Light card against canvas | 1.06:1, ΔL\* 2 | 1.19:1, ΔL\* 6.6 |
| Brass meanings | 8 or more | 3 (reward, focus and selected outline, the one primary control) |
| Radii in code | 10 | 3 + capsule |

## 8. Structural recommendations

### 8.1 Information architecture

| Today | Proposed | Why |
|---|---|---|
| Library | **Dungeon** | Says where the game happens; the screen subtitle gives the plain meaning |
| Hero, Armory (two tabs, equip split) | **Hero** and **Armory**, with slot rows opening a gear sheet | One flow to equip |
| Bestiary, Trophies (More) | **Codex**: segmented Monsters / Trophies | Two collections, one empty-state pattern, one fewer tab |
| More ▸ Settings | **Settings** (a tab) | No system "More" list |
| Lifetime stats in Hero and Settings | Hero only | One home for the data |
| Restore in the Armory header | Settings ▸ Purchases, and the Armory footer | Utilities leave prime space |

The gem chip in every header opens the Armory. With no analytics, an IA change that touches the shop cannot be measured except in App Store Connect sales; keeping Armory a tab protects that.

### 8.2 Screen by screen

- **Dungeon home** (spec in section 10.1). Header, hero stage, one panel holding the next dive and its single brass plate, a three-figure storage strip, two-line quest rows. Dates, Focus, Hunt Chosen and Duplicates move into one **Choose what to clean** sheet. Nine blocks become five.
- **Combat.** Full-screen focused mode: no tab bar. A top bar of exit (44 pt), five room pips and a combo chip. The photo takes at least 72% of the card. One glass strip: monster chip, one plain reason, size and age. No reward on the card. Keep and Delete equal weight. An Undo pill for 5 seconds. A coach mark on the first card. 16 elements become 8.
- **Room Summary.** Pinned commit bar: "Move 12 to Recently Deleted" over "48 MB · recoverable for 30 days". No in-app alert. Title "Room 2", not "Room Cleared"; the reward moment plays after the move succeeds and carries the honest sentence: "Space frees when Recently Deleted empties."
- **Onboarding.** Three screens (Promise, Permission, First room), then straight into a coached first room. Race, class and look arrive as "Level up your look" after the first Room Summary. The permission screen can never trap the user. 9 taps become 3.
- **Hero.** The stage is the screen: figure 160 pt or taller. Slots are a 2×3 grid; an empty slot says what to equip.
- **Codex.** A first-run banner ("Clear your first room and the Bestiary starts to fill"). Family tiles keep their art; hues change per 7.3.
- **Armory.** Themed segmented filter; aligned grid; state labels (Owned, Equipped, Next goal, "150 more gems"); full-opacity names on locked items.
- **Settings.** Cleanup, Recently Deleted with Open Photos, Appearance (Mode only), Purchases, Privacy and About (policy link, support, credits, version), then Reset. No stats.
- **Defeat** disappears with D1; if it stays, it says what happened plainly and never sells.

### 8.3 Component patterns

Twelve components cover everything above: `Button` (primary plate, destructive, secondary, quiet), `Panel`, `Chip`, `Stat`, `ProgressBar` (bar and room pips), `Notice`, `EmptyState`, `Row` (quest, slot, setting; themed toggle and segmented control), `SwipeCard`, plus the screen compositions `DungeonHome`, `RoomSummary`, `Onboarding`. Each has states, rules and a live preview in the design-system artifact.

## 9. Design-system audit (`design:design-system`)

**Score 45 / 100.** Rubric: tokens 11/25, components 8/25, consistency 7/20, accessibility 10/15, documentation and enforcement 9/15.

**Naming.** A prefix zoo: `Dungeon*` (`DungeonPanelBackground`, `DungeonProgressBar`, `DungeonRadius`, `DungeonBackgroundView`), `Gold*`, `*View` (`GemCounterView`, `XPBarView`, `HPBarView`, `HeroStageView`), `*Chip`, `*Tile`. Colours mix metaphor and role (`dungeonStoneLight` is "raised"; `xpViolet` is green; `gemEmerald` means five things). Proposed: role names (7.9) and a `PQ` prefix for components, with deprecated aliases for one release.

**Token coverage** (Views, excluding the vector avatar)

| Category | Defined | Found |
|---|---|---|
| Colour | 8 accents, 3 neutrals, 3 text, gold | 32 raw `.white`, 15 raw `.black`, 26 distinct tint opacities |
| Spacing | none | 15 distinct stack spacings; 23 distinct padding literals; 48% of padding and 53% of stack spacing off a 4 pt grid |
| Typography | 7 Cinzel styles | 28 fixed-size fonts (12 at 8 to 10 pt); 234 system text styles |
| Radius | 3 (8, 12, 16) | 10 distinct; tokens used 8 times, literals about 190 |
| Elevation | 1 panel shadow | 7 ad hoc `.shadow(` |
| Motion | a rule, no tokens | 8 spring curves, 7 durations |

**Component completeness**

| Component | Variants | States | Docs | Score |
|---|---|---|---|---|
| `GoldButtonStyle` (primary) | 1 (`fullWidth`) | default, pressed, disabled; no loading, no focus | rule 2 | 5/10 |
| Secondary, destructive, quiet button | none (84 hand-rolled `Button`s) | none | none | 0/10 |
| `DungeonPanelBackground` | accent, elevated, fill | no selected, pressed, disabled | rule 3 | 6/10 |
| `DungeonProgressBar` | tint, height | value only; good a11y | rule 5 | 7/10 |
| Level, streak, gem chips | 3 separate structs | none | none | 4/10 |
| `StatTile` | 1 | none | none | 4/10 |
| Segmented control, toggle | system defaults | system | none | 0/10 |
| Notice / banner | event banner only | none | none | 2/10 |
| Empty state, sheet scaffold, screen header | none | none | none | 0/10 |
| `HeroStageView` | accent, height | animated flag | rule 1 | 6/10 |

**Priority actions.** 1. Token files and lint (Phase 2). 2. `Button` with four variants. 3. `Notice` and `EmptyState`. 4. Themed segmented control and toggle. 5. One `ScreenHeader` so every tab titles itself the same way.

## 10. Handoff specifications (`design:design-handoff`)

Tokens are named, never raw values. "Edit" files are the likely touch points.

### 10.1 Dungeon home

**Overview.** The first screen after onboarding and the daily entry point. A first-timer must find the next action in two seconds. **Edit:** `DashboardView.swift`, `ContentView.swift`, new components.

**Layout (one column, gutter `space-4`, sections `space-6` apart).**

| Zone | Content | Tokens |
|---|---|---|
| Header | `display` "Dungeon"; trailing gem chip (opens Armory) | `display`, `ice-tint`, `ice` |
| Stage | Hero figure ≥160 pt on a pedestal; level chip top-left, streak chip top-right; torch pool behind | `radius-l`, `surface`, `elev-1`, `brass-tint` (radial, ≤10%) |
| Next dive | Theme line-art tile, `title` theme name, `meta` plain description ("A mixed haul · about 100 items · 5 rooms"), the **brass plate** "Enter the Dungeon", quiet "Choose what to clean ›" | `Panel`, `plate-*`, `glow-brass` |
| Storage strip | Three `Stat`s: To review, In Recently Deleted, Freed | `figure-m`, `eyebrow`, `text-3` for an unmeasured dash |
| Quests | `headline` "Today's quests" with `meta` "0 of 4"; two-line `Row`s in one panel | `Row`, `brass-tint` reward chips |

**States and interactions.**

| Element | State | Behaviour |
|---|---|---|
| Plate | Pressed | scale 0.98, 90 ms, haptic medium; starts the mixed dive |
| Plate | Loading | spinner replaces the icon; label stays; screen not blocked |
| Choose what to clean | Tap | Opens a sheet (`overlay`, `radius-l`): Blur, Screenshots, Large video, Old, Duplicates, a date range, Pick items. Choosing one starts a dive for that choice only |
| Gem chip | Tap | Opens the Armory |
| Storage strip | Info tap | Sheet explaining the three numbers |
| Access limited or denied | Always | A `Notice` under the header, with Manage or Open Settings |
| Seasonal event | When active | Dismissible `Notice` with an illustration slot, above the next dive |

**Edge cases.** No items to review: the plate reads "Nothing to review", disabled, with "Choose what to clean" still available. A date range on: the storage strip's first figure adds "in range" and a clear control appears in the sheet row. Long hero names truncate in the stage, never in the header. At accessibility Dynamic Type sizes the strip stacks to one column and the stage shrinks to 120 pt.

**Motion.** Screen-in: stage fades 280 ms, panels rise 8 pt with a 40 ms stagger. The plate halo is static.

**Accessibility.** Order: header, stage (labelled "Valkyrie hero"), next dive, plate, storage, quests. The plate's label is "Enter the Dungeon, mixed dive". Minimum 44 pt targets. Reduce Motion: no rise.

### 10.2 Combat card and HUD

**Edit:** `CombatView.swift`, `CombatHUD.swift`, `SwipeMediaCard.swift`. Hide the tab bar (`.toolbar(.hidden, for: .tabBar)`).

| Part | Spec |
|---|---|
| Top bar | Exit 44×44; five pips for rooms (`ProgressBar` segmented); combo chip. One line, no wrapping; the theme name is shown once, in room 1, as a subtitle, not in the bar |
| Card | `radius-l`, `elev-2`, photo ≥72% of height |
| Chip (top-left) | `glass` + `on-glass`, family icon + monster name, no family hue |
| Strip (bottom) | `glass`: reason line in `on-glass`; `meta` for size (`ice-on-glass`) and age (`on-glass-2`). "Review carefully" becomes a `brass-on-glass` ribbon, and then **no reward preview** appears anywhere on the card |
| Decisions | Keep (`surface`, `patina` shield) and Delete (`ember-fill`, `on-ember`), equal width, 56 pt |
| Undo | Glass pill above the buttons for 5 s after any decision; rewinds one step |
| Coach mark | First card only: two arrows with labels, dismissed by the first swipe or tap |

**Interactions.** Drag right commits Keep, left Delete, at 110 pt (existing). Stamps tint `patina` or `ember` up to 45%. Keeping never changes HP, combo or time (D1). **Edge cases.** Video: duration chip top-right on glass; a Live Photo chip; shade (already purged) shows a neutral chip "Already deleted once". **Accessibility.** Keep and Delete are VoiceOver actions plus the adjustable action. Exit has a label and a confirm only if marked items exist.

### 10.3 Room Summary

**Edit:** `RoomSummaryView.swift`. Header `display` "Room 2" over `subhead` "12 marked, 8 kept". A three-figure `Stat` row (To move, Items, Reward; the reward is quiet). A three-column grid, tap to flip; marked tiles get an `ember` ring and trash chip, kept tiles a `patina` veil and shield; no text below `meta`. The pinned bar is `overlay` with `elev-3`: **destructive** two-line button, then quiet "Keep all, skip room". Tapping the button goes **straight to the system delete dialog**; delete the in-app alert. If nothing is marked the header reads "Nothing marked" and the commit is replaced by a `secondary` "Next room". After success: a `patina` `Notice` ("Moved 12 · 48 MB. Space frees when Recently Deleted empties", action Open Photos) and the reward moment. **Edge cases:** more than 40 marked (grid scrolls under the bar); 0 videos; 1 item ("Move 1 to Recently Deleted").

### 10.4 Onboarding, permission step

**Edit:** `OnboardingView.swift`, `AppState.swift`. One plate. Copy: "Allow photo access / PurgeQuest reads your library to find clutter. Deleted items move to Recently Deleted for 30 days." States: not determined (plate "Allow photo access"); authorized (auto-advance); limited (`brass` `Notice`, "Continue" enabled); denied or restricted (`ember` `Notice`, plate becomes **Open Settings** and opens `UIApplication.openSettingsURLString`). On `scenePhase == .active`, re-read status and advance if granted. The pager must not allow swiping past this step while unauthorized (disable scrolling, `.scrollDisabled`). **Accessibility:** announce the Notice; the plate's label reflects its current action.

## 11. Roadmap

Effort: S ≤ ½ day, M 1 to 2 days, L 3 to 5 days, for one engineer using the CI screenshot loop. These are estimates, not measurements.

### Phase 0: trust floor, before submitting 1.0 (about 4 to 5 days)

| # | Item | Fixes | Effort | Acceptance |
|---|---|---|---|---|
| 0.1 | Access handling: Open Settings action, foreground re-check, no swipe past the gate, and a real authorization check before every dive and in the Library (a `Notice`, never "All clear") | S-02 | M | Deny, then allow in Settings, return: the flow continues unaided; revoke access later: the Library shows the Notice, not "All reviewed" |
| 0.2 | Decision D1: remove spare damage, defeat and Rally behind a flag; rename "Perfect Room" | S-01 | M | A user can spare 20 of 20 and finish the dive; tests updated |
| 0.3 | `*-on-glass` constants on the card's meta strip | A-02 | S | Measured 4.5:1 or better in Light and Dark over a white photo |
| 0.4 | Raise `textTertiary` and pill text to 4.5:1; raise the tests to match | A-02 | S to M | `ThemePaletteTests` asserts 4.5 for every text role on every ground |
| 0.5 | Copy and defect sweep: "1 day", "+150 gems" to "150 more gems", Trophies and Settings titles, truncation, tab-bar and status-bar bleed, two plates on permission, fixed fonts under 12 pt, spelling | S-04, S-12, S-13, A-05, A-09 | M | Screenshot tour shows none of them |
| 0.6 | Combat chrome: hide tab bar, one-line HUD with pips, theme once, 44 pt exit | S-06 | M | First card shows 8 persistent elements |
| 0.7 | Room Summary: pinned commit with count, remove the in-app alert, retitle | S-07 | M | Commit visible without scrolling at 20 items |
| 0.8 | Storage wording (from the launch checklist) | S-04 | S | No "freed" for bytes in Recently Deleted |

### Phase 1: clarity (1.1, about 2 weeks)

Onboarding rebuild (3 screens, deferred character creation, coached first room). Undo. Dungeon home restructure and the Choose-what-to-clean sheet. Codex merge, first-run banners and empty states. Glossary microcopy (Appendix B). Hero stage at full size. Add Room Summary, the duplicate card and the More list (if kept) to the screenshot tour.

### Phase 2: the system (1.2, about 2 to 3 weeks)

`PQTokens.swift` (colour, type, space, radius, elevation, motion). Swap to Verdigris Vault and Parchment (D2). Build `Button`, `Panel`, `Chip`, `Stat`, `Notice`, `EmptyState`, `Row`, themed segmented control and toggle. Migrate screen by screen using the 7.9 map. **Add lint to `repo_guard.py`:** no `.system(size:)` under 12 pt or outside icon glyphs; no corner-radius literal outside the tokens; no `.opacity(0.` literal outside token files; padding and spacing literals only from the scale; no raw `.white`/`.black` outside tokens; family ΔE at least 17; every text role at least 4.5:1 on all four grounds in both themes.

### Phase 3: elevation (ongoing)

Bespoke line-art for quest, theme and empty states. Choreograph Room Cleared, level-up, discovery and unlock. Redraw the app icon (D6). Polish Parchment. Re-shoot the App Store screenshots from the new screens (the launch checklist's six shots).

**Sequencing.** If the launch date is fixed, ship Phase 0, test on TestFlight, then Phase 1. If it can move two weeks, add Phase 1 before submission: the first-session experience is what App Store reviews will describe.

### Risks

| Risk | Mitigation |
|---|---|
| D1 changes economy and tests | Behind a flag; gems and XP unchanged; Rally hidden, not deleted |
| IA merge hides the shop | Armory stays a tab; gem chip opens it; compare App Store Connect sales across the release |
| Palette swap invalidates screenshots | Do it in Phase 2, then re-shoot once |
| Contrast regressions | Lint (above) makes them build failures |
| A new hue (orchid) | D5; the rule is amended, not silently broken |

## 12. Validation plan

Five people who have not seen the app, each on their own iPhone with a real library, moderated, about 20 minutes. No priming. Tasks and pass criteria:

1. Install, open, get to the first card. **Pass:** under 60 seconds, no help, nobody stuck at permission.
2. Review one room, keep at least 8 photos. **Pass:** nobody asks why keeping hurts; nobody loses.
3. Commit the room. **Pass:** 4 of 5 find the commit unaided; all can say where the photos went.
4. Probes: "Which button keeps the photo?"; "What happens to deleted photos?"; "What does Freed mean?"; "What is an Elite?". **Pass:** 4 of 5 correct on the first three.
5. Single ease question and the System Usability Scale. **Target:** SUS 80 or higher.

Run it once on today's TestFlight build (a baseline for S-01 to S-03 and S-06 to S-08) and again after Phase 1. A finding that five users do not trip over is demoted. There is no in-app analytics by design, so this is the measurement; the free instruments are TestFlight feedback and App Store Connect.

## Appendix A: evidence and reproduction

Run from `ios/PurgeQuest` unless noted. `X='--exclude=MiniAvatar*'`.

```sh
# gold: 110 uses of the accent in 27 files; 44 plate-token uses
grep -rn 'questAmber' Views --include=*.swift $X | wc -l
grep -rnE 'goldInk|goldFill|goldRim|goldPlate|buttonStyle\(\.gold' Views --include=*.swift $X | wc -l
# radii (10 distinct) and tokens used
grep -rhoE 'cornerRadius: ?[0-9]+(\.[0-9]+)?' Views --include=*.swift $X | sed 's/ //g' | sort | uniq -c | sort -rn
grep -rhoE 'DungeonRadius\.(chip|card|hero)' Views --include=*.swift | wc -l
# panels: 16 shared vs 45 hand-rolled
grep -rn 'DungeonPanelBackground' Views --include=*.swift | grep -v 'struct ' | wc -l
grep -rnE 'fill\(Color\.dungeonStone(Light)?[^)]*\)' Views --include=*.swift $X | wc -l
# fixed-size fonts: 28 (12 at 8 to 10 pt); Cinzel 39 vs system 234
grep -rnE '\.font\(\.system\(size: ?[0-9]+' Views --include=*.swift $X | wc -l
# tint opacities, spacing, padding, springs
grep -rhoE '\.opacity\(0\.[0-9]+\)' Views --include=*.swift $X | sort -u | wc -l
grep -rhoE 'spacing: ?[0-9]+' Views --include=*.swift $X | sort -n | uniq -c
grep -rhoE '\.spring\(response: ?[0-9.]+, ?dampingFraction: ?[0-9.]+\)' Views --include=*.swift $X | sort -u | wc -l
```

**Measured from pixels** (CI screenshots at 1206×2622; panel background and text ink sampled): Light combat, file size text `#1F7452` on the panel: 2.20:1; XP `#8A6210`: 2.38:1; Dark size `#3D9E76`: 3.79:1. **Computed from tokens:** WCAG 2 contrast and CIEDE2000 from the values in `ThemePalette.swift` (Appendix: the method is the standard formulae; reproducing it takes about 80 lines of Python and is worth wiring into a design lint). **Screen geometry** (Library, from `tour-dark-10-library.png`, 2000 px display height): ledger 290 to 826 (27%); plate top 1198 (60%); combat strip 1215 to 1580 of a card spanning 575 to 1602 (36%).

## Appendix B: microcopy

| Today | Use |
|---|---|
| Clean your Digital Dungeon and Tidy Your Digital Keep! | Clear the clutter. Keep the memories. |
| Your library is a dungeon. Photos and videos hide as monsters. Clear the depths and reclaim your storage. | Swipe to decide. Deleted photos wait 30 days in Recently Deleted. Everything stays on your iPhone. |
| Identified opportunity / Pending deletion / Actually reclaimed | To review / In Recently Deleted / Freed |
| Not yet verified | an em dash, `text-3` |
| Storage freed / Total freed | Moved to Recently Deleted / Total moved |
| Focused Dive / Hunt Chosen | Choose what to clean / Pick items |
| SPARE / Spare this item, take damage | Keep (no penalty) |
| Confirm Purge | Move 12 to Recently Deleted |
| Room Cleared (before a purge) | Room 2 |
| +150 gems (a shortfall) | 150 more gems |
| 1 days | 1 day |
| Defeat 3 Leviathans over 2 minutes | Delete 3 videos longer than 2 minutes |
| Standard gear tier / Dashboard Strip / Palette | Gear / Home preview / Theme |
| Summoning monsters from your library… | Scanning your library… (with a count) |

**Glossary shown at first encounter.** Dive: one session of up to five rooms. Room: 20 items. Elite: a boss-tier monster that pays more. Shade: a photo you deleted before; deleting it again pays nothing.
