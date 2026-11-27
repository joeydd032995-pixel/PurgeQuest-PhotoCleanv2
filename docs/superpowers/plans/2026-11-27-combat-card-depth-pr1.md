# Combat card depth, PR 1: depth and commit feel (implementation plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the combat card tilts and lifts with the drag, the threshold crossing is a single felt detent, and the full-card colour wash is replaced by an edge-weighted crimson tear (delete) and brass barrier (keep), all with deliberate Reduce Motion and Low Power versions.

**Architecture:** a Foundation-only model (`Models/CardFX.swift`: `FXGate`, `LightSource`, `SwipeProgress`, `EdgeOverlay`) decides every number; views (`ExhibitFrame`, two new overlay views, `SwipeMediaCard`) only render them. The model joins the Linux harness. Gameplay timing, rewards and the commit rule are untouched.

**Tech Stack:** Swift 6 / SwiftUI, iOS 18 deployment target, Swift Testing, the repo's Linux harness (`tools/swift_harness/run.sh`), XCUITest tour. No new dependencies, no assets, no Metal.

**Source:** `docs/superpowers/specs/2026-11-27-combat-card-depth-design.md` sections 3 and 4 (PR 1 of its three-PR rollout, section 8). Skins (PR 2) and combo, video and Live Photo cues (PR 3) are **not** in this plan, so `ComboTier`, `ComboCue`, `FamilySkinKind` and `SeededGeometry` are not built here.

## Global Constraints

- Deployment target iOS 18.0; no third-party SDKs, no network (`tools/ci/repo_guard.py` enforces it); no new image or audio assets.
- Pure models are `import Foundation` only, marked `nonisolated`, and listed in **both** lists in `tools/swift_harness/run.sh`. Tests use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`).
- The photo interior is never tinted, desaturated, blurred or covered **at rest**. The drag overlays are the only thing that reaches into the photo, only while a finger is down, and are bounded: the tear at most 34% of the card's width and the barrier at most 24%, strongest at the edge and fading to nothing inward, edge alpha at most 0.55 and 0.5.
- Under `FXGate.still` (Reduce Motion **or** Low Power Mode): no tilt, no punch, no pull, and the armed state shows at once (the stamp at full strength). **Lift is kept**: it is the drag itself.
- Gameplay timing is unchanged: `onDelete` and `onSpare` fire 220 ms after the commit (80 ms under Reduce Motion), exactly as today. The commit's snap-away is tied to Reduce Motion only, not to Low Power. Commit is decided by the gesture's raw translation (`> 110 pt`), never by the pull.
- Action word is "Keep". The DELETE and KEEP stamps stay; the KEEP stamp stays patina, the barrier is brass.
- Every effect view is `allowsHitTesting(false)` and `accessibilityHidden(true)`. VoiceOver actions on the card are untouched.
- Haptics stay silenced by Reduce Motion (`HapticsService.reduceMotion`), as today.
- Light direction is one constant: 15 degrees left of vertical (`LightSource`).
- Nothing merges without the owner's explicit ask. No Swift toolchain exists in the authoring container: **CI is the first compile.** The fast signals are `swift-pure-logic` (about 1 minute) and `build-and-analyze` (about 4 minutes); `unit-tests` takes about 35.

## File structure

| File | Change |
|---|---|
| Create `ios/PurgeQuest/Models/CardFX.swift` | `FXGate`, `LightSource`, `SwipeProgress`, `EdgeOverlay` (pure) |
| Create `ios/PurgeQuestTests/CardFXTests.swift` | 17 harness tests |
| Modify `tools/swift_harness/run.sh` | Add `Models/CardFX` and `CardFXTests` to the two lists |
| Modify `ios/PurgeQuest/Services/HapticsService.swift` | `detentDelete()`, `detentKeep()` |
| Modify `ios/PurgeQuest/Views/Components/ExhibitFrame.swift` | `lift`, `highlightShift`; photo lift; frame shadow and bevel from `LightSource` |
| Create `ios/PurgeQuest/Views/Combat/CardFX/TearOverlay.swift` | `TearShape`, `TearOverlay` |
| Create `ios/PurgeQuest/Views/Combat/CardFX/BarrierOverlay.swift` | `BarrierShape`, `BarrierOverlay` |
| Modify `ios/PurgeQuest/Views/Combat/SwipeMediaCard.swift` | Gate, progress, tilt, punch, pull, detent, overlays, tour pose |
| Modify `ios/PurgeQuest/UITestSupport.swift` | `cardPoseWidth` (`-UITestCardPose`) |
| Modify `ios/PurgeQuestUITests/AppearanceTourUITests.swift` | `testZCardDragPoses` |
| Modify docs | Spec errata, D7 and D8 in `UI_ASSESSMENT.md`, README harness count |

---

### Task 0: Merge the spec PR and move the work onto the session branch

**Files:** none (git only).

- [ ] **Step 1: Confirm PR #46 is green on its head and merge it** (the owner asked for this on 27 November). Use a merge commit, as the repo's history does: `merge_pull_request` with `merge_method: "merge"` and `expectedHeadSha` set to the PR's head.
- [ ] **Step 2: Restart the session branch from the new main.**

```bash
git fetch origin main
git checkout claude/purgequest-ui-ux-spec-f7cryw
git reset --hard origin/main      # the branch holds only history that is now in main
```

- [ ] **Step 3: Bring the local work over.** Until this task is done, work is committed on the local branch `wip-card-depth-pr1` and **nothing is pushed**: pushing before the spec PR merges would put code on a docs-only PR.

```bash
git cherry-pick origin/main..wip-card-depth-pr1   # exactly the commits not already in main
git log --oneline -8
git push -u origin claude/purgequest-ui-ux-spec-f7cryw   # a fast-forward: main's merge commit descends from the old tip; if the merge was a squash, use --force-with-lease (the branch then holds only already-merged history)
```
Expected: the plan and every task commit so far sit directly on `origin/main`, and CI starts on the branch.

---

### Task 1: The `CardFX` model and its tests

**Files:**
- Create: `ios/PurgeQuest/Models/CardFX.swift`
- Create: `ios/PurgeQuestTests/CardFXTests.swift`
- Modify: `tools/swift_harness/run.sh` (both lists)

**Interfaces:**
- Produces:
  - `FXGate { case live, still; init(reduceMotion: Bool, lowPowerMode: Bool); var isStill: Bool }`
  - `LightSource { static let angleDegrees: Double; static var direction: (x: Double, y: Double); static func shadowOffset(depth: Double) -> (x: Double, y: Double); static func highlightPoints(shiftDegrees: Double) -> (start: (x: Double, y: Double), end: (x: Double, y: Double)) }`
  - `SwipeProgress { enum Side { case delete, keep }; static let threshold: Double; init(dx: Double, dy: Double, gate: FXGate, wasArmed: Side?); armed: Side?; side: Side?; signed: Double; strength: Double; tiltY: Double; tiltX: Double; lift: Double; pull: Double; highlightShift: Double }`
  - `EdgeOverlay { static func tearWidth(strength:armed:) -> Double; static func barrierWidth(strength:armed:) -> Double; static func tearAlpha(strength:) -> Double; static func barrierAlpha(strength:) -> Double }`
- Consumes: nothing.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/CardFXTests.swift`:

```swift
import Testing
import Foundation
@testable import PurgeQuest

@Suite struct CardFXTests {

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    // MARK: Gate

    @Test func reduceMotionOrLowPowerMakesEveryEffectAStill() {
        #expect(FXGate(reduceMotion: false, lowPowerMode: false) == .live)
        #expect(FXGate(reduceMotion: true, lowPowerMode: false) == .still)
        #expect(FXGate(reduceMotion: false, lowPowerMode: true) == .still)
        #expect(FXGate(reduceMotion: true, lowPowerMode: true) == .still)
        #expect(FXGate.still.isStill)
        #expect(!FXGate.live.isStill)
    }

    // MARK: Light

    @Test func theLightDirectionIsAUnitVectorLeaningRight() {
        let d = LightSource.direction
        #expect(close(d.x * d.x + d.y * d.y, 1))
        #expect(d.x > 0, "the torch is left of centre, so light travels right")
        #expect(d.y > 0.9, "and mostly down")
    }

    @Test func aShadowOffsetFollowsTheLightAndScalesWithDepth() {
        let shallow = LightSource.shadowOffset(depth: 2)
        let deep = LightSource.shadowOffset(depth: 10)
        #expect(close(deep.x, shallow.x * 5))
        #expect(close(deep.y, shallow.y * 5))
        #expect(deep.x > 0 && deep.y > deep.x)
        let none = LightSource.shadowOffset(depth: 0)
        #expect(none.x == 0 && none.y == 0)
    }

    @Test func theHighlightRunsFromTheLitSideAndSwingsWithTheShift() {
        let rest = LightSource.highlightPoints()
        #expect(rest.start.y < rest.end.y, "from the top, where the torch is")
        #expect(rest.start.x < rest.end.x)
        #expect(close((rest.start.x + rest.end.x) / 2, 0.5) && close((rest.start.y + rest.end.y) / 2, 0.5))
        let swung = LightSource.highlightPoints(shiftDegrees: 20)
        #expect(swung.start.x < rest.start.x, "a positive shift swings the light's start point left and down")
        #expect(swung.start.y > rest.start.y)
    }

    // MARK: Progress and arming

    @Test func progressIsSignedAndClamped() {
        #expect(close(SwipeProgress(dx: -55, dy: 0, gate: .live).signed, -0.5))
        #expect(close(SwipeProgress(dx: 55, dy: 0, gate: .live).signed, 0.5))
        #expect(SwipeProgress(dx: -900, dy: 0, gate: .live).signed == -1)
        #expect(SwipeProgress(dx: 900, dy: 0, gate: .live).signed == 1)
        #expect(close(SwipeProgress(dx: -55, dy: 0, gate: .live).strength, 0.5))
        #expect(SwipeProgress(dx: -10, dy: 0, gate: .live).side == .delete)
        #expect(SwipeProgress(dx: 10, dy: 0, gate: .live).side == .keep)
    }

    @Test func noDragIsNotArmed() {
        let p = SwipeProgress(dx: 0, dy: 0, gate: .live)
        #expect(p.armed == nil)
        #expect(p.side == nil)
        #expect(p.signed == 0)
    }

    @Test func armsAtTheThresholdAndHoldsDownToNinetyPercent() {
        var p = SwipeProgress(dx: -109, dy: 0, gate: .live)
        #expect(p.armed == nil, "109 of 110 is not there yet")
        p = SwipeProgress(dx: -110, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == .delete, "arms exactly at the threshold")
        p = SwipeProgress(dx: -100, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == .delete, "91% still holds")
        p = SwipeProgress(dx: -98, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == nil, "89% lets go")
        p = SwipeProgress(dx: -100, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == nil, "and 91% does not arm again from nothing")
    }

    @Test func aWobbleAroundTheThresholdArmsOnce() {
        var armedCount = 0
        var wasArmed: SwipeProgress.Side? = nil
        for dx in [-111.0, -109.0, -111.0, -108.0, -112.0, -107.0] {
            let p = SwipeProgress(dx: dx, dy: 0, gate: .live, wasArmed: wasArmed)
            if p.armed != nil && wasArmed == nil { armedCount += 1 }
            wasArmed = p.armed
        }
        #expect(armedCount == 1, "one detent, not six")
    }

    @Test func crossingToTheOtherSideNeedsTheFullThreshold() {
        let p = SwipeProgress(dx: 100, dy: 0, gate: .live, wasArmed: .delete)
        #expect(p.armed == nil, "armed for delete does not carry over to keep at 91%")
        let q = SwipeProgress(dx: 110, dy: 0, gate: .live, wasArmed: .delete)
        #expect(q.armed == .keep)
    }

    // MARK: Tilt

    @Test func tiltFollowsTheDragAndIsClamped() {
        #expect(close(SwipeProgress(dx: 55, dy: 0, gate: .live).tiltY, 10.0 / 3))
        #expect(SwipeProgress(dx: 165, dy: 0, gate: .live).tiltY == 10)
        #expect(SwipeProgress(dx: 5000, dy: 0, gate: .live).tiltY == 10)
        #expect(SwipeProgress(dx: -5000, dy: 0, gate: .live).tiltY == -10)
        #expect(SwipeProgress(dx: 0, dy: 220, gate: .live).tiltX == -8)
        #expect(SwipeProgress(dx: 0, dy: -220, gate: .live).tiltX == 8)
        #expect(close(SwipeProgress(dx: 165, dy: 0, gate: .live).highlightShift, 20), "the light swings 20 degrees at full tilt")
    }

    @Test func tiltIsOffUnderTheGate() {
        let p = SwipeProgress(dx: 165, dy: 220, gate: .still)
        #expect(p.tiltY == 0)
        #expect(p.tiltX == 0)
        #expect(p.highlightShift == 0)
    }

    @Test func liftGrowsWithDistanceAndSurvivesTheGate() {
        #expect(SwipeProgress(dx: 0, dy: 0, gate: .live).lift == 0)
        #expect(close(SwipeProgress(dx: 30, dy: 40, gate: .live).lift, 50.0 / 60))
        #expect(SwipeProgress(dx: 600, dy: 0, gate: .live).lift == 1)
        #expect(close(SwipeProgress(dx: 30, dy: 40, gate: .still).lift, 50.0 / 60), "never remove the sense of lift")
    }

    // MARK: Pull

    @Test func pullIsDeleteOnlyAndStartsPastTheThreshold() {
        #expect(SwipeProgress(dx: -110, dy: 0, gate: .live).pull == 0, "nothing at the line itself")
        #expect(close(SwipeProgress(dx: -120, dy: 0, gate: .live).pull, -2.5), "a quarter of the 10 pt beyond")
        #expect(SwipeProgress(dx: -400, dy: 0, gate: .live).pull == -24, "capped at 24 pt")
        #expect(SwipeProgress(dx: 200, dy: 0, gate: .live).pull == 0, "keep has no pull: the barrier holds the card")
    }

    @Test func pullIsOffUnderTheGate() {
        #expect(SwipeProgress(dx: -400, dy: 0, gate: .still).pull == 0)
    }

    // MARK: Edge overlays

    @Test func edgeOverlaysNeverExceedTheirLimits() {
        for step in 0...20 {
            let s = Double(step) / 20
            for armed in [false, true] {
                #expect(EdgeOverlay.tearWidth(strength: s, armed: armed) <= 0.34 + 1e-12)
                #expect(EdgeOverlay.barrierWidth(strength: s, armed: armed) <= 0.24 + 1e-12)
            }
            #expect(EdgeOverlay.tearAlpha(strength: s) <= 0.55 + 1e-12)
            #expect(EdgeOverlay.barrierAlpha(strength: s) <= 0.5 + 1e-12)
        }
        #expect(EdgeOverlay.tearWidth(strength: 7, armed: true) <= 0.34 + 1e-12, "out-of-range strength is clamped")
        #expect(EdgeOverlay.tearAlpha(strength: -3) == 0)
    }

    @Test func armingWidensTheTearAndTheBarrier() {
        #expect(EdgeOverlay.tearWidth(strength: 1, armed: true) > EdgeOverlay.tearWidth(strength: 1, armed: false))
        #expect(EdgeOverlay.barrierWidth(strength: 1, armed: true) > EdgeOverlay.barrierWidth(strength: 1, armed: false))
        #expect(close(EdgeOverlay.tearWidth(strength: 1, armed: true), 0.34))
        #expect(close(EdgeOverlay.barrierWidth(strength: 1, armed: true), 0.24))
    }

    @Test func nothingShowsWithoutADrag() {
        #expect(EdgeOverlay.tearWidth(strength: 0, armed: false) == 0)
        #expect(EdgeOverlay.barrierWidth(strength: 0, armed: false) == 0)
        #expect(EdgeOverlay.tearAlpha(strength: 0) == 0)
        #expect(EdgeOverlay.barrierAlpha(strength: 0) == 0)
    }
}
```

- [ ] **Step 2: Register the model and its tests in the harness.** In `tools/swift_harness/run.sh`, in the first `for f in ...` list append ` Models/CardFX` after `Models/ShopPricing`, and in the second `for t in ...` list append ` CardFXTests` after `ShopPricingTests`.

- [ ] **Step 3: Commit the tests first.** The red run is not observable here: there is no Swift toolchain, and CI cannot run before Task 0 has moved the work onto the session branch. The order is still tests first (this commit, before the model's). CI's first run of them is the green run, and the first red it can show is a genuine failure to fix.

```bash
git add ios/PurgeQuestTests/CardFXTests.swift tools/swift_harness/run.sh
git commit -m "Tests first: CardFX gate, light, swipe progress and edge overlay limits"
```

- [ ] **Step 4: Write the model.** Create `ios/PurgeQuest/Models/CardFX.swift`:

```swift
//
//  CardFX.swift
//  PurgeQuest
//
//  The numbers behind the combat card's depth and commit feel (design:
//  docs/superpowers/specs/2026-11-27-combat-card-depth-design.md, sections 3 and 4). Views render what this
//  decides and decide nothing themselves. Foundation only, so the Linux harness checks it.
//

import Foundation

/// Whether decorative effects run. Reduce Motion or Low Power Mode turns every one of them into a still.
nonisolated enum FXGate: Equatable {
    case live
    case still

    init(reduceMotion: Bool, lowPowerMode: Bool) {
        self = (reduceMotion || lowPowerMode) ? .still : .live
    }

    var isStill: Bool { self == .still }
}

/// One torch for every lit surface on the card. It sits at the top, 15 degrees left of vertical, so light
/// travels down and slightly right and shadows fall the same way.
nonisolated enum LightSource {
    static let angleDegrees: Double = 15

    /// A unit vector in screen coordinates (y points down): the way the light travels.
    static var direction: (x: Double, y: Double) {
        let a = angleDegrees * .pi / 180
        return (sin(a), cos(a))
    }

    /// Where a shadow of this depth falls, in points.
    static func shadowOffset(depth: Double) -> (x: Double, y: Double) {
        let d = direction
        return (d.x * depth, d.y * depth)
    }

    /// Gradient end points, in the unit square, for a highlight that starts on the lit side. `shiftDegrees` swings
    /// the light, so a tilting card catches it differently.
    static func highlightPoints(shiftDegrees: Double = 0) -> (start: (x: Double, y: Double), end: (x: Double, y: Double)) {
        let a = (angleDegrees + shiftDegrees) * .pi / 180
        let sx = sin(a) / 2
        let sy = cos(a) / 2
        return ((0.5 - sx, 0.5 - sy), (0.5 + sx, 0.5 + sy))
    }
}

/// What a drag looks like: how far toward Delete or Keep, how the card tilts and lifts, whether the commit line has
/// been crossed. `dx` is negative toward Delete. The gesture's raw translation, not any number here, decides a commit.
nonisolated struct SwipeProgress: Equatable {
    enum Side: Equatable { case delete, keep }

    /// The commit line, in points. Matches `SwipeMediaCard.commitThreshold`.
    static let threshold: Double = 110
    /// Arms at the full threshold and lets go below 90%, so jitter at the line cannot repeat a haptic.
    static let armAt: Double = 1.0
    static let disarmBelow: Double = 0.9
    static let maxTiltY: Double = 10
    static let maxTiltX: Double = 8
    /// The drag distance at which the photo has fully lifted.
    static let liftDistance: Double = 60
    /// Past the line, the card is drawn this fraction of the excess toward the tear, up to the cap (points).
    static let pullFactor: Double = 0.25
    static let pullCap: Double = 24
    /// Degrees the light swings per degree of Y tilt: 20 at full tilt.
    static let highlightSwing: Double = 2

    let dx: Double
    let dy: Double
    let gate: FXGate
    /// The side the card is armed for, with hysteresis from `wasArmed`.
    let armed: Side?

    init(dx: Double, dy: Double, gate: FXGate, wasArmed: Side? = nil) {
        self.dx = dx
        self.dy = dy
        self.gate = gate
        let side: Side? = dx < 0 ? .delete : (dx > 0 ? .keep : nil)
        let ratio = abs(dx) / Self.threshold
        if let side, ratio >= Self.armAt {
            armed = side
        } else if let side, wasArmed == side, ratio >= Self.disarmBelow {
            armed = side
        } else {
            armed = nil
        }
    }

    var side: Side? { dx < 0 ? .delete : (dx > 0 ? .keep : nil) }

    /// -1 (full Delete) to +1 (full Keep).
    var signed: Double { min(1, max(-1, dx / Self.threshold)) }

    /// 0 to 1, how far toward whichever side.
    var strength: Double { abs(signed) }

    var tiltY: Double {
        gate.isStill ? 0 : min(1, max(-1, dx / (Self.threshold * 1.5))) * Self.maxTiltY
    }

    var tiltX: Double {
        gate.isStill ? 0 : -min(1, max(-1, dy / (Self.threshold * 2))) * Self.maxTiltX
    }

    /// 0 to 1. Not gated: it is the drag itself, so the sense of lift never goes away.
    var lift: Double { min(1, (dx * dx + dy * dy).squareRoot() / Self.liftDistance) }

    /// A cosmetic nudge toward the tear, in points (negative is left). Delete only; the barrier holds the card.
    var pull: Double {
        guard !gate.isStill, dx < -Self.threshold else { return 0 }
        return -min(Self.pullCap, Self.pullFactor * (-dx - Self.threshold))
    }

    /// Degrees the frame's lit edge swings with the tilt.
    var highlightShift: Double { tiltY * Self.highlightSwing }
}

/// The reach of the two drag overlays, as fractions of the card's width. The tear is a jagged crimson void from the
/// left edge, the barrier a brass ward along the right. Both are strongest at the edge and fade to nothing inward,
/// and neither can ever pass its limit.
nonisolated enum EdgeOverlay {
    static let tearMaxWidth: Double = 0.34
    static let barrierMaxWidth: Double = 0.24
    static let tearEdgeAlpha: Double = 0.55
    static let barrierEdgeAlpha: Double = 0.5
    /// How much of the full width an unarmed overlay reaches; arming opens it to the whole.
    static let unarmedShare: Double = 0.8

    static func tearWidth(strength: Double, armed: Bool) -> Double {
        tearMaxWidth * clamp(strength) * (armed ? 1 : unarmedShare)
    }

    static func barrierWidth(strength: Double, armed: Bool) -> Double {
        barrierMaxWidth * clamp(strength) * (armed ? 1 : unarmedShare)
    }

    static func tearAlpha(strength: Double) -> Double { tearEdgeAlpha * clamp(strength) }

    static func barrierAlpha(strength: Double) -> Double { barrierEdgeAlpha * clamp(strength) }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}
```

- [ ] **Step 5: Commit the model.** The first CI run of the harness (after Task 0) must pass: 17 new tests, harness 439 in 33 suites. If a boundary assertion fails (floating point on the 90% line), adjust the **test's** inputs away from the exact boundary, never the thresholds.

```bash
git add ios/PurgeQuest/Models/CardFX.swift
git commit -m "CardFX: the gate, one light source, swipe progress and edge overlay limits"
```

---

### Task 2: Two haptic detents

**Files:**
- Modify: `ios/PurgeQuest/Services/HapticsService.swift` (after `videoSlash()`, before `comboBurst()`)

**Interfaces:**
- Produces: `HapticsService.detentDelete()`, `HapticsService.detentKeep()` (both `@MainActor`, both silent under `reduceMotion`).
- Consumes: nothing.

- [ ] **Step 1: Add the methods.** Insert after the closing brace of `videoSlash()`:

```swift
    /// The delete detent: the card crossing the commit line on a left drag. Sharp and short.
    func detentDelete() {
        guard !reduceMotion else { return }
        transient(intensity: 1.0, sharpness: 0.9) { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    }

    /// The keep detent: the same moment on a right drag, softer and rounder, so keeping feels protective.
    func detentKeep() {
        guard !reduceMotion else { return }
        transient(intensity: 0.45, sharpness: 0.15) { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }

    /// One Core Haptics tap, or the plain generator when the hardware has no engine.
    private func transient(intensity: Float, sharpness: Float, fallback: () -> Void) {
        guard supportsHaptics, let engine else { fallback(); return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback()
        }
    }
```

- [ ] **Step 2: Commit** (verified by the compile in Task 5's push).

```bash
git add ios/PurgeQuest/Services/HapticsService.swift
git commit -m "Haptics: a sharp delete detent and a soft keep detent"
```

---

### Task 3: The frame lifts the photo and catches the light

**Files:**
- Modify: `ios/PurgeQuest/Views/Components/ExhibitFrame.swift`

**Interfaces:**
- Consumes: `LightSource.shadowOffset(depth:)`, `LightSource.highlightPoints(shiftDegrees:)`.
- Produces: `ExhibitFrame(chip:accent:lift:highlightShift:photo:)`; `lift` and `highlightShift` default to 0, so `DuplicateGroupCard`'s existing call is unchanged.

- [ ] **Step 1: Add the two properties** after `let accent: Color`:

```swift
    /// 0...1: how far the photo has lifted off the frame, from the drag. 0 at rest.
    var lift: Double = 0
    /// Degrees the frame's lit edge swings with the card's tilt. 0 at rest.
    var highlightShift: Double = 0
```

- [ ] **Step 2: Replace `body`** with:

```swift
    var body: some View {
        let photoShadow = LightSource.shadowOffset(depth: 3 + 7 * lift)
        photo()
            .clipShape(RoundedRectangle(cornerRadius: outer - rim))
            .overlay(RoundedRectangle(cornerRadius: outer - rim).stroke(Color.black.opacity(0.55), lineWidth: 1))
            .overlay(alignment: .bottomLeading) { chipView }
            .scaleEffect(1 + 0.03 * lift)
            .shadow(color: .black.opacity(0.30 * lift), radius: 3 + 9 * lift, x: photoShadow.x, y: photoShadow.y)
            .padding(rim)
            .background(frameBackground)
    }

    /// The bronze rim: the plate gradient, the accent and dark keylines, a faint lit edge that moves with the tilt,
    /// and a shadow that deepens as the photo lifts. Light and shadow both come from `LightSource`.
    private var frameBackground: some View {
        let frameShadow = LightSource.shadowOffset(depth: 2 + 4 * lift)
        let points = LightSource.highlightPoints(shiftDegrees: highlightShift)
        return RoundedRectangle(cornerRadius: outer)
            .fill(LinearGradient.goldPlate)
            .overlay(RoundedRectangle(cornerRadius: outer).stroke(accent.opacity(0.5), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: outer).stroke(Color.black.opacity(0.6), lineWidth: 0.5).padding(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: outer - 1)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0), Color.black.opacity(0.25)],
                            startPoint: UnitPoint(x: points.start.x, y: points.start.y),
                            endPoint: UnitPoint(x: points.end.x, y: points.end.y)
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            )
            .shadow(color: .black.opacity(0.25 + 0.15 * lift), radius: 5 + 8 * lift, x: frameShadow.x, y: frameShadow.y)
    }
```

- [ ] **Step 3: Commit.**

```bash
git add ios/PurgeQuest/Views/Components/ExhibitFrame.swift
git commit -m "Exhibit frame: the photo lifts with the drag and the rim catches one light"
```

---

### Task 4: The tear and the barrier

**Files:**
- Create: `ios/PurgeQuest/Views/Combat/CardFX/TearOverlay.swift`
- Create: `ios/PurgeQuest/Views/Combat/CardFX/BarrierOverlay.swift`

**Interfaces:**
- Consumes: `EdgeOverlay.tearWidth/tearAlpha/barrierWidth/barrierAlpha`.
- Produces: `TearOverlay(strength: Double, armed: Bool, animated: Bool)` and `BarrierOverlay(strength: Double, armed: Bool, animated: Bool)`, both filling the space they are given.

- [ ] **Step 1: Create `TearOverlay.swift`:**

```swift
//
//  TearOverlay.swift
//  PurgeQuest
//
//  The delete drag's overlay (design section 4): a jagged void that grows from the card's left edge as the drag
//  grows, widening when the commit line is crossed. It replaces the old full-card crimson wash, which tinted the
//  whole photo. Strongest at the edge, gone by 34% of the card's width, so most of the picture stays clear.
//

import SwiftUI

/// The tear's outline: a deterministic zigzag, so it never flickers. `edgeOnly` is just the jagged edge, for a stroke.
struct TearShape: Shape {
    /// Fraction of the rectangle's width the tear reaches at its deepest.
    var widthFraction: Double
    var edgeOnly = false

    var animatableData: Double {
        get { widthFraction }
        set { widthFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let depth = rect.width * widthFraction
        guard depth > 0.5 else { return path }
        let steps = 14
        func point(_ i: Int) -> CGPoint {
            let t = Double(i) / Double(steps)
            let jag = i.isMultiple(of: 2) ? 1.0 : 0.6
            let wobble = 0.85 + 0.15 * sin(t * 9)
            return CGPoint(x: rect.minX + depth * jag * wobble, y: rect.minY + rect.height * t)
        }
        path.move(to: edgeOnly ? point(0) : CGPoint(x: rect.minX, y: rect.minY))
        for i in 0...steps { path.addLine(to: point(i)) }
        if !edgeOnly {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct TearOverlay: View {
    /// 0...1: how far the drag has gone toward Delete.
    let strength: Double
    /// True once the commit line is crossed: the tear opens wider and its edge brightens.
    let armed: Bool
    /// False under Reduce Motion or Low Power: the armed shape then shows at once.
    let animated: Bool

    var body: some View {
        let width = EdgeOverlay.tearWidth(strength: strength, armed: armed)
        let alpha = EdgeOverlay.tearAlpha(strength: strength)
        ZStack {
            TearShape(widthFraction: width)
                .fill(LinearGradient(
                    colors: [
                        Color.black.opacity(alpha),
                        Color.combatCrimsonDeep.opacity(alpha * 0.7),
                        Color.combatCrimson.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: UnitPoint(x: max(width, 0.01), y: 0.5)
                ))
            TearShape(widthFraction: width, edgeOnly: true)
                .stroke(Color.combatCrimson.opacity(min(1, alpha * (armed ? 1.8 : 1.2))), lineWidth: armed ? 2.5 : 1.5)
        }
        .animation(animated ? .spring(response: 0.18, dampingFraction: 0.6) : nil, value: armed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Create `BarrierOverlay.swift`:**

```swift
//
//  BarrierOverlay.swift
//  PurgeQuest
//
//  The keep drag's overlay (design section 4): a brass ward that rises along the card's right edge as the drag
//  grows and locks, brighter, when the commit line is crossed. Defensive, not celebratory: a bowed line and a soft
//  inward glow, gone by 24% of the card's width. The KEEP stamp stays patina; only the barrier is brass.
//

import SwiftUI

/// The ward's outline: the card's right edge and a quadratic arc bowing inward. `edgeOnly` is just the arc.
struct BarrierShape: Shape {
    var widthFraction: Double
    var edgeOnly = false

    var animatableData: Double {
        get { widthFraction }
        set { widthFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let depth = rect.width * widthFraction
        guard depth > 0.5 else { return path }
        // A quadratic curve reaches half of its control offset, so the control sits 2x depth in for an arc `depth` deep.
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - depth * 2, y: rect.midY)
        )
        if !edgeOnly { path.closeSubpath() }
        return path
    }
}

struct BarrierOverlay: View {
    /// 0...1: how far the drag has gone toward Keep.
    let strength: Double
    /// True once the commit line is crossed: the ward widens, thickens and brightens.
    let armed: Bool
    /// False under Reduce Motion or Low Power: the armed shape then shows at once.
    let animated: Bool

    var body: some View {
        let width = EdgeOverlay.barrierWidth(strength: strength, armed: armed)
        let alpha = EdgeOverlay.barrierAlpha(strength: strength)
        ZStack {
            BarrierShape(widthFraction: width)
                .fill(LinearGradient(
                    colors: [
                        Color.questAmber.opacity(alpha),
                        Color.questAmber.opacity(alpha * 0.35),
                        Color.questAmber.opacity(0)
                    ],
                    startPoint: .trailing,
                    endPoint: UnitPoint(x: 1 - max(width, 0.01), y: 0.5)
                ))
            BarrierShape(widthFraction: width, edgeOnly: true)
                .stroke(Color.questAmber.opacity(min(1, alpha * (armed ? 2.0 : 1.4))), lineWidth: armed ? 3 : 1.5)
        }
        .animation(animated ? .spring(response: 0.18, dampingFraction: 0.6) : nil, value: armed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 3: Commit.**

```bash
git add ios/PurgeQuest/Views/Combat/CardFX
git commit -m "Card FX: the delete tear and the keep barrier, edge-weighted and bounded"
```

---

### Task 5: Wire it into the card

**Files:**
- Modify: `ios/PurgeQuest/Views/Combat/SwipeMediaCard.swift`
- Modify: `ios/PurgeQuest/UITestSupport.swift`

**Interfaces:**
- Consumes: everything from Tasks 1 to 4; `UITestSupport.cardPoseWidth`.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Add the tour hook** to `UITestSupport.swift`, after `forcedEventID`, and document it in the header list (`//    -UITestCardPose <L|R><points>   the front card is drawn mid-drag, e.g. L125 or R55`):

```swift
    /// The front card's drag pose for the tour, from `-UITestCardPose L125` (125 points toward Delete) or `R55`
    /// (55 toward Keep), or nil. The card is drawn as if held there with no finger down, because a UI test cannot hold
    /// a finger and take a screenshot at once.
    static var cardPoseWidth: Double? {
        #if DEBUG
        guard isTour,
              let raw = UserDefaults.standard.string(forKey: "UITestCardPose"),
              let first = raw.first,
              let points = Double(raw.dropFirst()) else { return nil }
        switch first {
        case "L": return -points
        case "R": return points
        default:  return nil
        }
        #else
        return nil
        #endif
    }
```

- [ ] **Step 2: State and helpers in `SwipeMediaCard`.** After `@Environment(\.scenePhase) private var scenePhase` add:

```swift
    @State private var armedSide: SwipeProgress.Side? = nil
    @State private var punch: CGFloat = 1
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
```

After the `rotation` property add:

```swift
    private var gate: FXGate { FXGate(reduceMotion: reduceMotion, lowPowerMode: lowPower) }

    private var progress: SwipeProgress {
        SwipeProgress(dx: Double(dragOffset.width), dy: Double(dragOffset.height), gate: gate, wasArmed: armedSide)
    }
```

- [ ] **Step 3: Replace the transform chain in `body`.** Replace

```swift
        .scaleEffect(isFront ? 1.0 : 0.94)
        .offset(x: snapAway?.width ?? dragOffset.width, y: snapAway?.height ?? dragOffset.height)
        .rotationEffect(snapAway == nil ? rotation : .degrees(Double((snapAway?.width ?? 0) / 14)))
        .gesture(isFront ? dragGesture : nil)
```

with

```swift
        .rotation3DEffect(.degrees(progress.tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(progress.tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .scaleEffect(isFront ? punch : 0.94)
        .offset(
            x: snapAway?.width ?? (dragOffset.width + CGFloat(progress.pull)),
            y: snapAway?.height ?? dragOffset.height
        )
        .rotationEffect(snapAway == nil ? rotation : .degrees(Double((snapAway?.width ?? 0) / 14)))
        .gesture(isFront ? dragGesture : nil)
        .onChange(of: dragOffset) { _, _ in updateArming() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: item.id) {
            // Tour only: draw the front card mid-drag, with no finger down.
            guard isFront, let pose = UITestSupport.cardPoseWidth else { return }
            try? await Task.sleep(for: .milliseconds(400))
            dragOffset = CGSize(width: pose, height: 0)
        }
```

- [ ] **Step 4: Lift and light into the frame.** In `cardBody`, change the `ExhibitFrame(` call to:

```swift
            ExhibitFrame(
                chip: Wording.exhibitChip(size: item.formattedSize, age: item.ageDescription),
                accent: item.monsterType.accentColor,
                lift: progress.lift,
                highlightShift: progress.highlightShift
            ) { photoLayer }
```

- [ ] **Step 5: Replace both overlays.** Replace `deleteOverlay` and `spareOverlay` entirely with:

```swift
    private var deleteOverlay: some View {
        let strength = max(0, min(1, -dragOffset.width / commitThreshold))
        // Under the gate the armed state shows at once: the stamp jumps to full strength.
        let stamp = (gate.isStill && armedSide == .delete) ? 1.0 : strength
        return ZStack {
            TearOverlay(strength: strength, armed: armedSide == .delete, animated: !gate.isStill)
            Text("DELETE")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .padding(10).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.combatCrimsonDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1))
                .rotationEffect(.degrees(-12))
                .opacity(stamp)
                .scaleEffect(0.6 + stamp * 0.5)
                .position(x: 110, y: 80)
        }
        .allowsHitTesting(false)
    }

    private var spareOverlay: some View {
        let strength = max(0, min(1, dragOffset.width / commitThreshold))
        let stamp = (gate.isStill && armedSide == .keep) ? 1.0 : strength
        return ZStack(alignment: .topTrailing) {
            BarrierOverlay(strength: strength, armed: armedSide == .keep, animated: !gate.isStill)
            Text("KEEP")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.onAccent)
                .padding(10).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gemEmeraldDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1))
                .rotationEffect(.degrees(12))
                .opacity(stamp)
                .scaleEffect(0.6 + stamp * 0.5)
                .padding(.top, 60)
                .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
```

- [ ] **Step 6: Add the detent.** After `dragGesture` and before `commit`, add:

```swift
    /// Keeps `armedSide` in step with the drag and fires the detent once per crossing.
    private func updateArming() {
        guard isFront, snapAway == nil else { return }
        let next = progress.armed
        guard next != armedSide else { return }
        armedSide = next
        guard let side = next else { return }
        fireDetent(side)
    }

    /// The haptic, then a 150 ms scale punch (skipped under the gate).
    private func fireDetent(_ side: SwipeProgress.Side) {
        switch side {
        case .delete: HapticsService.shared.detentDelete()
        case .keep:   HapticsService.shared.detentKeep()
        }
        guard !gate.isStill else { return }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { punch = 1.03 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { punch = 1 }
        }
    }
```

`commit(left:)`, `dragGesture`, `commitThreshold` and the 220 ms and 80 ms delays are **not changed**.

- [ ] **Step 7: Push and read the compile.** Expected: `build-and-analyze` succeeds (about 4 minutes) and `swift-pure-logic` still passes. On a compile error read the job log (`get_job_logs`), fix the cause, push again.

```bash
git add ios/PurgeQuest/Views/Combat/SwipeMediaCard.swift ios/PurgeQuest/UITestSupport.swift
git commit -m "Combat card: tilt, lift, a threshold detent, a pull into the tear, and edge-weighted overlays"
git push
```

---

### Task 6: The tour shoots the poses

**Files:**
- Modify: `ios/PurgeQuestUITests/AppearanceTourUITests.swift` (after `testZRoomSummaryAndDuplicateCard`)

- [ ] **Step 1: Add the test.** Insert after `captureRoomSummary(_:)`'s closing brace:

```swift
    /// The card caught mid-drag, short of the commit line and past it, toward Delete and toward Keep. The app draws the
    /// pose itself (`-UITestCardPose`), because a UI test cannot hold a finger down and take a screenshot at once.
    /// Best-effort, like the Room Summary test: a pose that does not come up is a note, not a failure. The name starts
    /// with Z so it runs last.
    @MainActor
    func testZCardDragPoses() {
        let poses: [(name: String, value: String)] = [
            ("left-half", "L55"), ("left-armed", "L125"), ("right-half", "R55"), ("right-armed", "R125")
        ]
        for mode in ["dark", "light"] {
            for pose in poses { captureCardPose(mode, name: pose.name, value: pose.value) }
        }
    }

    @MainActor
    private func captureCardPose(_ mode: String, name: String, value: String) {
        let app = launch(mode, phase: "main", extra: ["-UITestCardPose", value])
        guard app.tabBars.firstMatch.waitForExistence(timeout: 25) else {
            note("card pose \(name) (\(mode)): the tab bar did not appear")
            app.terminate()
            return
        }
        dismissPhotoPrompt()
        settle(1.5)
        let enter = app.buttons["Enter the dungeon and start a cleanup session"]
        guard enter.waitForExistence(timeout: 10) else {
            note("card pose \(name) (\(mode)): the Enter button was not found")
            app.terminate()
            return
        }
        enter.tap()
        dismissPhotoPrompt()
        // The scan: a plain sleep, nothing asks the app anything until it has finished.
        settle(25.0)
        shot("\(mode)-15-card-\(name)")
        app.terminate()
    }
```

- [ ] **Step 2: Commit and push.** The tour runs the whole `AppearanceTourUITests` class, so the new test joins it with no workflow change.

```bash
git add ios/PurgeQuestUITests/AppearanceTourUITests.swift
git commit -m "Tour: shoot the card mid-drag, left and right, short of the line and past it"
git push
```

---

### Task 7: Record the decisions and fix the spec

**Files:**
- Modify: `docs/superpowers/specs/2026-11-27-combat-card-depth-design.md`
- Modify: `docs/design/UI_ASSESSMENT.md` (decisions table, after the D6 row)
- Modify: `README.md` (line with the Linux harness count)

- [ ] **Step 1: Spec errata.** Append to the spec a section `## 12. Errata found while planning PR 1 (27 November 2026)`:
  1. **Invariant 1 versus the drag overlays.** Invariant 1 now reads: *at rest* the photo interior is never tinted, desaturated, blurred or covered, and the family skins never touch it at any time; the drag overlays are the one bounded exception, only while a finger is down: the tear at most 34% of the card's width and the barrier at most 24%, edge alpha at most 0.55 and 0.5, fading to nothing inward. (As first written, the 34% tear contradicted "a band of at most 8%".) The tour's skins-on and skins-off pixel diff (PR 2) compares the card **at rest**.
  2. **Commit timing.** Gameplay timing is 220 ms, and 80 ms under Reduce Motion, as today (section 3.3, invariant 6 said only 220). The commit row in section 3.4 is tied to Reduce Motion only: Low Power keeps the spring snap, because it costs nothing and changing it would change timing for those players.
- [ ] **Step 2: Decisions table.** In `UI_ASSESSMENT.md`, after the D6 row add:

```markdown
| D7 | Motion and family hues versus the 27 November UI spec | **The new spec supersedes the older rules**, amended narrowly, only where a sub-project uses it (`docs/superpowers/specs/2026-11-27-combat-card-depth-design.md`, 27 November 2026) | Rule 8, the family-hue rule of 7.3 and E-7 are amended by the sub-project that needs each, not up front |
| D8 | How family skins are built | **Procedural SwiftUI**: no new art, no Metal; a `FamilySkin` seam lets one family move to a shader later | PR 2 of the card design |
```

- [ ] **Step 3: README count.** On the Linux harness row, change "422 tests in 32 suites" to "439 tests in 33 suites" and add "the card's swipe, tilt, light and overlay limits" to the list of what it covers.
- [ ] **Step 4: Commit and push.**

```bash
git add docs README.md
git commit -m "Docs: record D7 and D8, correct two points in the card spec, update the harness count"
git push
```

---

### Task 8: Open the PR and say what was and was not verified

- [ ] **Step 1: Open the PR** from `claude/purgequest-ui-ux-spec-f7cryw` into `main`, titled "Combat card depth, PR 1: tilt, lift, detent and edge-weighted overlays". The description states: what changed; that gameplay timing, rewards and the commit rule are untouched; the two spec errata; the ci results actually seen (`swift-pure-logic`, `build-and-analyze`, `unit-tests`, the tour artifact); and that **frame rate, thermals, Reduce Motion, Low Power, VoiceOver and Dynamic Type were not run** and need the owner's device pass.
- [ ] **Step 2: Subscribe to the PR's activity** and work every red check to its root cause. Do not merge: that takes the owner's own ask.

---

## Self-review (spec coverage)

| Spec requirement (PR 1) | Task |
|---|---|
| `CardFX` pure model, harness-registered | 1 |
| Tilt Y 10, X 8, off under the gate | 1, 5 |
| Photo lift 1.03 and shadow; kept under the gate | 1, 3, 5 |
| Frame shadow and bevel from one `LightSource`; highlight swings with tilt | 1, 3 |
| Threshold detent: hysteresis, two haptics, 150 ms punch | 1, 2, 5 |
| Pull into the tear, delete only, cosmetic | 1, 5 |
| Edge-weighted tear (34%) and barrier (24%) replacing the wash; stamps stay; KEEP stamp patina | 1, 4, 5 |
| Reduced versions: armed state instant, stamps full, no punch or pull | 5 |
| Gameplay timing unchanged | 5 (untouched code) |
| Harness tests, tour pose shots | 1, 6 |
| Doc records and errata | 7 |
| Not in this PR: skins, combo cues, video, Live Photo, the skins-on and off pixel diff | PRs 2 and 3 |
