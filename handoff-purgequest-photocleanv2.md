# active-memory handoff: PurgeQuest-PhotoCleanv2 combat card work (PR #49 green, awaiting the owner)

**Handoff #1** · 2026-11-28 · Lineage: #1 (2026-11-28): combat card parts 1 to 3 merged (#46, #47, #48); fix PR #49 with the skin second pass is green and waiting on the owner's decision

## 0. Instructions for Claude (read first)

You are continuing work from a previous chat. That chat is gone; this file is the complete context and the source of truth.

1. Read this whole file before replying.
2. Follow sections 3 (Style), 4 (Hard rules) and 5 (Corrections) in every reply, for the rest of this chat. They override your defaults.
3. Use the values in section 8 exactly. Never round, re-estimate, or "correct" them.
4. Do not suggest anything listed in section 7 (Changed / rejected) again unless the user brings it up.
5. Code word: None active. If the user types /amcodeword, start every reply with the phrase they choose (default "Yes Boss!").
6. Your first reply: at most 5 lines covering the goal, the current state, and the next step (section 11). Mention any files from section 13 that were not attached. Ask the questions in section 12 if there are any. End with "Ready to continue with <next step>?" Then wait for the user's go.

## 1. Mission
- **Goal:** Implement, one sub-project at a time, the owner's 7-workstream UI/UX spec for PurgeQuest-PhotoCleanv2 (an offline, pure-SwiftUI iOS photo-cleanup game; repo `joeydd032995-pixel/PurgeQuest-PhotoCleanv2`). The 7 workstreams, in the owner's order: (1) combat card: depth, family skins, overlays, combo, video; (2) atmosphere and light; (3) hero presence; (4) dashboard; (5) onboarding; (6) sound and haptics; (7) material, typography, share card.
- **State:** Workstream 1 is built (Part 1 PR #47, Parts 2 and 3 PR #48, both merged) and its fixes are in PR #49 (open, green). Workstreams 2 to 7 are not started and each needs its own design.
- **Done looks like:** each workstream gets a design spec, a plan, and PRs that pass all six CI checks, with CI-tour screenshots the owner judges. Nothing merges without the owner's ask.
- **Context:** the owner follows a cloud Claude Code session in the Claude app and reviews through screenshots and PR descriptions. The container has no Swift toolchain, so CI is the only compile and the only test run.

## 2. About the user (as relevant to this work)
- The repo owner. Gives terse commands ("Check", "Merge now and continue on with parts 2 and 3") and expects verified, faithful reports.
- Judges the look from screenshots; will do the on-device pass themselves (frame rate, thermals, Reduce Motion, Low Power Mode, VoiceOver, Dynamic Type).
- Writes in English. Approves network and environment changes through the tool approval prompts.

## 3. Style & communication
- **Language:** English.
- **Tone:** direct and factual. Say plainly what is verified and what is not. No hype.
- **Reply length:** short status plus findings. When the owner's input is needed, end with one clear decision question and a recommendation.
- **Formatting:** GitHub-flavored markdown, short sections, tables for before and after. No emojis (the active-memory checkpoint hook has its own format).
- **Working style:** use the process skills first (superpowers:brainstorming before any creative work, then writing-plans, then executing-plans). One clarifying question at a time. Small verified steps. CI-first, because code is written blind. After pushing, open a PR (ready for review, not draft) and subscribe to its activity. Never poll or sleep for CI: events wake the session; keep a `send_later` safety-net check-in.
- **Avoid:** stale claims in PR descriptions; calling CI "passed" from a summary event; hiding that code was never compiled locally; ticking a bot's "Autofix" box; guessing what a screenshot shows without looking.

## 4. Hard rules (word for word)
1. "This spec supersedes the old rules" (decision D7, the owner's chosen option): the owner's UI/UX spec overrides the earlier design-system rules where they conflict. The narrow amendments are recorded in `docs/design/DESIGN_SYSTEM.md` rule 8 and the family-hue allowance, and in `docs/design/UI_ASSESSMENT.md`.
2. "A. Procedural SwiftUI (Recommended)" (decision D8): effects are procedural SwiftUI (Canvas, shapes, gradients). No new image assets, no Metal, no new dependencies, no network use.
3. Never merge or approve a PR without the owner's explicit ask. The owner asked to merge #46, #47 and #48. They have not yet asked to merge #49.
4. At rest, the photo interior is never tinted, desaturated, blurred or covered. Skins draw only on the frame rim (clipped to the rim ring) and in two 10 pt side bands. The drag tear and barrier are the one bounded exception, and only while a finger is down. `CardSkinInvarianceTests` enforces this and must keep passing.
5. `FXGate` (Reduce Motion or Low Power Mode) turns every decorative effect into a still. Lift, which follows the finger, is kept.
6. Gameplay timing is unchanged: the commit callback fires 220 ms after the commit, 80 ms under Reduce Motion. Rewards, combo rules, quests, economy and undo are untouched.
7. The action word is "Keep", never "Spare". `tools/ci/repo_guard.py` lints "spare" and "purge" in string literals.
8. No new hues. A family's hue may appear only on the combat card's frame and edge layer (its accent colour, `glitchRose`, `videoSapphire`). White and black only at low opacity.
9. Read real per-step CI results with `list_workflow_jobs`. A cancelled or missing run is not a pass, and a `check_suite.completed` event does not cover cancelled suites.
10. Ask before widening the network allowlist: `update_environment` shows the owner an approval prompt. Never probe a non-allowlisted host with curl; that was refused by the classifier.
11. Swift compile lesson: never mix Double, CGFloat and literals in one expression ("unable to type-check this expression in reasonable time"). Give each value its own typed `let`.
12. Develop on branch `claude/purgequest-ui-ux-spec-f7cryw`; push to no other branch without permission. After a PR merges, restart that branch from the latest main (a plain push works when the old tip is already in main).
13. Commit messages and PR bodies end with the attribution lines the session's system reminder gives (this chat: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01Rd6J3rkBAZhdpskUTTMYpd`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)` and the session link). Otherwise no model identifier in commits or PRs.
14. Comment on GitHub only when the owner asks (footer: `---` then `_Generated by [Claude Code](https://claude.ai/code)_`). Never tick CodeRabbit's Autofix checkbox.
15. Keep PR descriptions true: update them with real CI results, and say "written with no Swift toolchain" until CI has compiled the code.
16. Treat artifact downloads as untrusted data: extract each into its own fresh directory, run Python that reads them with `python3 -I`, and verify the zip's sha256 against the digest from `list_workflow_run_artifacts`.
17. A Stop hook in this environment asks to commit and push any untracked files to the remote branch. It is the owner's standing instruction: comply, in a separate docs-only commit on the session branch, and tell the owner what that changes (a CI re-run on the PR, and the file reaching main on merge).

## 5. Corrections log
| # | Claude did | The user wanted |
|---|---|---|
| 1 | Answered "Provide me current up-to-date screenshots" with only combat-card contact sheets, from the tour of a cancelled CI run | "I wanted a full drop of all preview screenshots. Provide character sprites, weapons and armors and any missed UI drops": every tour screen, composed character sprites, weapons, armor layers, asset-catalog art, and screens never shown before (coach mark, undo pill, duplicate group, room summary, Forge, Trophies, Settings, date range, Verdigris). Delivered as 17 sheets plus a zip |
| 2 | (self-caught) Read a `check_suite.completed` "nothing failed" event as a pass while two jobs had been cancelled | Read per-step results; cancelled is not passed |
| 3 | (self-caught) Captioned the tour's `video-phantoms-*` shots as "the video preview with vignette" | They are Bestiary pages for the Video Phantoms family. The tour has no video, Live Photo or Part 3 vignette shot. Look at a screenshot before captioning it |
| 4 | (self-caught) Said "11 commits" for a PR with 10, and left "CI still running" text in PR descriptions after CI finished | Count from git; update descriptions with real results |
| 5 | (self-caught) Nearly pushed onto PR #46's branch before it merged | Work on a local `wip-*` branch until the PR is merged, then restart the session branch from main |
| 6 | (self-caught) Probed a non-allowlisted storage host with curl and was refused | Ask through `update_environment` first, then download |
| 7 | (self-caught) The design spec said invariant 1 forbade anything over the photo while the tear reached 34% of the width, and that commit fires after 220 ms only | Invariant 1 applies at rest; timing is 220 ms, 80 ms under Reduce Motion (spec section 12) |

## 6. Decisions
| Decision | Why |
|---|---|
| The owner's spec supersedes the old design rules (D7) | owner: "This spec supersedes the old rules" |
| Procedural SwiftUI (D8) | owner: "A. Procedural SwiftUI (Recommended)" |
| Design sections for the combat card approved | owner: "Looks right, continue" twice, then "Looks right, write the spec" |
| Patch five gaps between the design and the owner's UI update | owner: "Yes" |
| Part 1 as PR #47; Parts 2 and 3 together as PR #48 | owner: "Merge PR #47 and continue on with parts number 2 and 3 on a new PR" |
| Merge with merge commits ("Merge pull request #N") | the repo's convention on main |
| PR #49 fixes: tear and barrier at the screen edges, wider rims with accent wash, room for the Undo pill, tour puts groups away, combo rim shots | owner: "open a new PR to implement any needed previous fixes or new-find fixes" |
| Second commit on #49 (`15b8299`): skin second pass, hide the card behind a duplicate group, tour waits out the Undo pill | owner: "add one more commit to it with the skin second pass and nits 1 and 2" |
| The gate job (`ios.yml`) skips `testZCardDragPoses`, `testZFamilySkins` and `testZComboRim` | screenshot-only; keeps `unit-tests` under its 45-minute cap; `ui-snapshots.yml` still runs them |
| `ui-snapshots.yml` timeout 70 minutes (was 60) | the job measures 51 to 53 minutes |
| Video vignette and breath, Live Photo glow and iris are not screenshotted | the synthetic library has no video or Live Photo; they need the owner's device pass |
| This handoff file is committed on the session branch as its own commit | a Stop hook asked to commit and push untracked files |

## 7. Changed / rejected
- Tear and barrier drawn on the card → drawn at the screen's left and right edges by `ScreenEdgeOverlay`, fed by the pure `EdgeSignal` (they slid off-screen with the card and were nearly invisible).
- Skins as hairlines on a 4 pt rim → rim +2 pt (Behemoths +4), accent wash, then a second pass with a mark per family.
- Duplicate group photo fixed at 250 pt → 140 to 250 pt, with 56 pt kept at the bottom for the Undo pill; the card behind a group is no longer drawn.
- Tour's first card could be a duplicate group → the tour puts a group away (Confirm, keep all copies) and waits out the Undo pill before shooting.
- ❌ Editing the Ashen Bough IV staff art (a grey smudge at its upper right): the asset tests pin each sprite's pixels. It is an art question for the owner.
- ❌ Using `docs/modular/verification/*` renders for the sprite drop: stale dev images with annotation text. Fresh sheets were built from the shipped art.
- ❌ Running the pose, skin and combo tours in the gate job (`ios.yml`): over its time budget.
- ❌ Ticking CodeRabbit's Autofix box (it would give the branch to a third-party bot).
- Keeping this handoff file untracked → committed on the session branch (a Stop hook asked; see rule 17).

## 8. Data & facts (exact)

**Repo and branches**
- Repo `joeydd032995-pixel/PurgeQuest-PhotoCleanv2`. Session branch `claude/purgequest-ui-ux-spec-f7cryw`. Base `main`.
- #46 spec docs, merged (`f1a9474`). #47 Part 1, merged (`70efd6a`). #48 Parts 2 and 3, merged as merge commit `7576b85` (its head was `7dae471`).
- **#49** "Combat card fixes from the first tour: tear and barrier at the screen edges, bolder skins, room for the Undo pill": open, not draft, code head `15b8299aac153d433f84cdd2f6ae53e44665ff4b` (earlier head `806f094`), base main `7576b85`, mergeable state clean at that head. 2 commits plus the second pass. **A docs-only commit adding this handoff file was then pushed on top (a Stop hook asked), so the PR's current head is one commit later: read it with `pull_request_read` before merging.** The code is identical to `15b8299`; CI was re-running on the new head when this was written.

**CI on #49 head `15b8299`: all six checks passed**
| Check | Time | Note |
|---|---|---|
| guard | 4 s | |
| assets | 1m12s | |
| swift-pure-logic | 1m02s | 468 tests in 35 suites |
| build-and-analyze | 3m05s | analyzer clean |
| unit-tests (cap 45 min) | 31m20s | steps: unit tests 4m22s, Forge UI tests 2m15s, non-gating tour 22m20s, onboarding reset test 1m42s (ran and passed) |
| tour (cap 70 min, ui-snapshots.yml) | 50m59s | tour step 46m15s |
- `unit-tests` on other heads: 38m24s (`806f094`), 35m14s (`7dae471`), 43m20s (#47). It varies 31 to 43 minutes with the runner, on the same code.
- Run ids on `15b8299`: unit-tests 46108340187, tour 46108340203, tour artifact id 15250550003 (sha256 `858298d4e88e4def96cfeaff694c13e7535922aaf4a2d8f0f7cb51c11cd01a24`, 106 PNGs, kept until 2026-12-12). Earlier tour artifacts: 15245732539 (`806f094`), 15241163369 (`7dae471`, 102 PNGs), unit-tests artifact 15241065669.
- Harness count is 468 tests in 35 suites (README line says so; 465 before the 3 `EdgeSignal` tests).

**Design numbers (combat card)**
- Commit line 110 pt; arms at 1.0 of it, disarms below 0.9. Tilt Y 10 degrees, X 8 degrees. Light 15 degrees left of vertical. Delete-side pull 0.25 of the excess, capped at 24 pt.
- Tear max width 0.34, barrier 0.24 (of the deck width since #49); edge alphas 0.55 and 0.5.
- Side bands 10 pt. Rim = 4 pt + `extraRim` (2 for dragons, undead, relics, phantoms, glitch; 4 for behemoths). Photo starts at least 14 pt in from the card edge; the invariance test compares from 20 pt.
- Edge particles drawn 1.6x size and 1.7x alpha. Particle budgets dragons 5, undead 12, relics 10, behemoths 0, phantoms 8, glitch 6. Glitch cycle 1.8 s, flick share 0.05.
- Phantoms glow radius 18 at alpha 0.85. `undoPillReserve` 56 pt. Group photo `minHeight 140`, `maxHeight 250`.
- Six families to skins: Duplicate Dragons, Clutter Undead, Archive Relics, Storage Behemoths, Video Phantoms, Glitchborn. Kill switch `FamilySkinKind.enabled`.

**Project settings**
- iOS 18.0 target; `SWIFT_VERSION = 5.0`; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; pure models are `nonisolated`. Xcode uses file-system synchronized groups (new files register themselves).
- Foundation-only models run on Linux via `tools/swift_harness/run.sh` (two lists: sources and tests). Tests use Swift Testing.
- Tour screenshots are 1206 x 2622 px.

**CI and artifacts, how it works here**
- No `gh` CLI; GitHub through the `mcp__github__*` tools. Read results with `get_check_runs`, `actions_list list_workflow_jobs` (per-step), `get_job_logs` (use a small `tail_lines`).
- Artifacts: `actions_list list_workflow_run_artifacts`, then `actions_get download_workflow_run_artifact` returns a signed URL that lasts about 10 minutes, on `productionresultssaNN.blob.core.windows.net`. The host must be allowlisted; then `curl -f -L -o`, check sha256, unzip into a fresh directory.
- Allowlisted on environment `PurgeQuest-PhotoCleanv2` (`env_01Hx6z6ET77EStKw1iowvTnx`): `productionresultssa5`, `sa6`, `sa16`, `sa18`, `sa31`, `sa32` (all `.blob.core.windows.net`). A new shard needs another approval.
- Scratchpad (may be cleared): `/tmp/claude-0/-home-user-PurgeQuest-PhotoCleanv2/5dfb7ede-8de9-5221-bd9b-a2571f433e90/scratchpad/` with `full-drop/` (17 sheets, a 31 MB zip, `heroes/`), `pr49-drop/`, `dl-full/`, `dl-pr49/`, `dl-pr49b/`, and scripts `make_drop.py`, `compose_rig.py` (static Spriter rig composer), `make_compare.py`, `make_compare2.py`, `make_crops_pr49.py`.

## 9. People, terms & names
- **People:** the owner (repo owner and the user); CodeRabbit bot (posts a "skipped review" comment on PRs; ignore).
- **Terms:** "the tour" = `AppearanceTourUITests`, the screenshot job. "The gate job" = `unit-tests` in `ios.yml`. "Armed" = dragged past the commit line. "Tear" = the delete-side overlay; "barrier" = the keep-side overlay. D7 and D8 = the two decisions in section 6. "Parts 1, 2, 3" = depth and drag; skins; combo, video and Live Photo. "Nit 1 and 2" = hide the card behind a duplicate group; tour waits out the Undo pill.
- **Names in use:**
  - Views: `ios/PurgeQuest/Views/Combat/CardFX/{TearOverlay,BarrierOverlay,ScreenEdgeOverlay,SkinRim,SkinEdgeLayer,ComboRim,VideoDressing,IrisTransition}.swift`, `SwipeMediaCard.swift`, `CombatView.swift`, `DuplicateGroupCard.swift`, `Views/Components/ExhibitFrame.swift`.
  - Models: `Models/CardFX.swift` (`FXGate`, `LightSource`, `SwipeProgress`, `EdgeOverlay`, `EdgeSignal`), `Models/CardSkin.swift`.
  - Tests: `CardFXTests`, `CardSkinTests`, `CardSkinInvarianceTests`.
  - Launch flags: `-UITestCardPose L125|R55`, `-UITestFamily <skin>`, `-UITestNoSkins`, `-UITestCombo <tenths>`.
  - UI tests: `testZCardDragPoses`, `testZFamilySkins`, `testZComboRim`, `testZRoomSummaryAndDuplicateCard`.
  - Docs: `docs/superpowers/specs/2026-11-27-combat-card-depth-design.md` (sections 1 to 14.1), `docs/superpowers/plans/2026-11-27-combat-card-depth-pr1.md` and `...-pr2-3.md`, `docs/design/DESIGN_SYSTEM.md`, `docs/design/UI_ASSESSMENT.md`.
  - Workflows: `.github/workflows/ios.yml`, `.github/workflows/ui-snapshots.yml`.

## 10. Work state
| Item | Status | Version / location | Notes |
|---|---|---|---|
| Workstream 1: combat card | built; fixes in #49 | #47, #48 merged; #49 open | Relics and Phantoms skins still subtle (see section 12) |
| PR #49 | open; all six checks green on code head `15b8299`; description updated with those results; a docs-only commit (this file) on top has CI re-running | current head = one commit past `15b8299` | Waiting on the owner: merge as is, or a third pass. Merge only once the re-run on the current head is green |
| Design spec | final for workstream 1 | sections 1 to 14.1 | Records what the first tour showed and the fixes |
| Full screenshot, sprite, weapon and armor drop | delivered to the owner | scratchpad `full-drop/` | 17 sheets plus a zip; composed heroes are my own approximation (idle pose, no recolor) |
| Skin verdict on the second pass (1:1) | done | PR #49 description | Unmistakable: Behemoths, Glitchborn, Undead, Dragons. Subtle: Phantoms, Relics |
| Part 3 visuals | partly shot | combo rim shots exist; video vignette and Live Photo glow and iris are not shot | Need fixtures with video and Live Photo, or the owner's device pass |
| Workstreams 2 to 7 | not started | none | Each needs brainstorm, spec, plan |
| Scheduled check-ins | none pending | none | The session is subscribed to #49 activity; re-subscribe in a new session if needed |
| This handoff file | written and committed as its own docs-only commit on the session branch (PR #49), because a Stop hook asked to commit and push untracked files | repo root `handoff-purgequest-photocleanv2.md` | If the owner merges #49 it lands on main; offer to remove it first (a follow-up commit deleting it) if they do not want it there |

## 11. Next steps
1. **Next action:** ask the owner whether to merge #49 as is (`merge_pull_request`, `merge_method` "merge", `expectedHeadSha` = the PR's current head, read it first; it is one docs-only commit past `15b8299aac153d433f84cdd2f6ae53e44665ff4b`, and the checks must be green on that head) or do a third pass on Archive Relics and Video Phantoms (about 50 minutes of CI). Recommended last time: merge. Touch nothing on #49 until they answer, apart from reading its CI.
2. If merged: restart `claude/purgequest-ui-ux-spec-f7cryw` from the latest main before any new work.
3. If a third pass: make the Relics cracks and patina and the Phantoms shimmer more visible, inside the rim ring only, keep `CardSkinInvarianceTests` passing, push, and read the per-step CI results before reporting.
4. Pick the next workstream (2 to 7) with the owner. The original spec text must be re-attached (section 13). Each one follows brainstorming, a spec, a plan, then PRs.
5. The owner's device pass is theirs. Optionally add a video and a Live Photo to the tour's simulator library so Part 3 can be screenshotted.

## 12. Open questions ⚠️
- Merge #49 as is, or a third pass on Archive Relics and Video Phantoms? (The design calls Relics quiet and archival, so quiet may be intended.)
- Ashen Bough IV (`weapon.staff.1.4`, file `ios/PurgeQuest/Art/Gear/staves/staff_1_4.png`; Ashen Bough V is `weapon.staff.1.5`): keep the grey smudge at its upper right, or will the owner supply fixed art? The asset tests pin sprite pixels, so changed art also needs its hashes updated.
- Gate job headroom: leave it (31 to 43 minutes of 45), raise the timeout, or trim the non-gating tour step in `ios.yml`? Not changed so far.
- Which of workstreams 2 to 7 is next? The owner's "Recommended Implementation Sequence" is not reproduced in this file.

## 13. Re-attach checklist
- [ ] The owner's original pasted spec ("Deep-dive UI/UX specification for PurgeQuest-PhotoCleanv2", 7 workstreams plus the recommended sequence): needed to design workstream 2 or later.
- [ ] Optional: the screenshot sheets in `full-drop/` and `pr49-drop/`: only for reviewing visuals again. They can be rebuilt from the CI artifacts for 14 days.

---
<sub>Audit: 13/13 sections · 17 rules · 7 corrections · 25 data points · secrets removed: none found · generated by active-memory</sub>
