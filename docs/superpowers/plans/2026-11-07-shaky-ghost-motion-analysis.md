# Shaky Ghost Motion Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Summon the Shaky Ghost from measured camera shake instead of from brightness changes between three far-apart frames.

**Architecture:** Decode a few short runs of consecutive small frames from each eligible video, estimate the global translation between neighbouring frames by block matching, and judge how much the camera's velocity jitters. All of the maths is deterministic Foundation code in one file (`CameraMotion.swift`) that runs on the Linux harness; a thin AVFoundation layer feeds it, off the main actor, under a per-clip and a per-dive time budget. `MonsterClassifier` consults the result.

**Tech Stack:** Swift 5 language mode, Foundation, AVFoundation, Photos, Swift Testing. No new dependencies.

**Roadmap item:** 4 of 4 ("Implement actual motion/shake analysis for Shaky Ghost"). Independent of the other plans. Where it touches the same files as another plan, the step says how.

## What the code actually does today (verified against the tree, not the README)

The README says the Shaky Ghost is "the default video fallback". It no longer is (ordinary clips now become Mist, Tatter or Void Wraiths), but the real signal is still not shake:

- `VideoFrameAnalysisService.signals(for:)` decodes **three** 128 px frames at 10 %, 50 % and 90 % of the clip and measures only **mean brightness** per frame.
- `VideoFrameSignals.meanMotion` is the mean absolute **brightness** difference between those frames. `isErratic` is `meanMotion >= 0.14`, and the classifier summons the Shaky Ghost on it (`MonsterClassifier.classifyVideo`).
- So any clip whose brightness differs a lot between its first, middle and last thirds is a Shaky Ghost: a cut to a darker room, a sunset, a camera panning from sky to ground. A genuinely shaky clip of a motionless, evenly lit scene is *not* one; it is called a **Framed Phantom** ("Frames barely change"), because `isStatic` also looks only at brightness.
- The existing test that asserts this (`erraticMotionUpgradesShakyGhost`) feeds the classifier `[0.3, 0.5, 0.35]`, three brightness numbers.

## Design

**Measuring motion.** For two consecutive frames `a` and `b` (160 px on the long edge, grayscale) try every whole-pixel shift in a window of plus or minus 8 px, keep the shift with the smallest mean absolute difference, and refine it with a parabola through the neighbouring costs. The estimate is refused when the frames are flat, when no shift beats the average candidate by 20 %, or when the best shift sits on the window's edge (a cut, or a pan faster than the window).

**Judging shake.** From the successive moves `v1, v2, …` of one window, camera shake is the *change* in velocity, not the velocity: a steady pan has large `v` and zero change. `jitter` is the RMS change between consecutive moves as a fraction of the picture's long edge, halved in energy so that a random tremor of size *s* reads *s*. `reversalRatio` is the share of consecutive moves that flipped direction (a tremor flips about half the time, a pan never). A clip is shaky when jitter is at least 0.010, reversals are at least 0.3, and at least 6 comparisons were measured (`ShakeSignals.isShaky`).

**Sampling.** Three windows at 15 %, 45 % and 75 % of the clip, each 7 frames 0.1 s apart (6 moves, 5 comparisons per window, 15 in all). Frames are decoded at exact times; a pair whose decoded timestamps are not about 0.1 s apart is discarded.

**Cost control.** Decoding exact frames is the expensive part and `PhotoLibraryService.buildMediaItems` processes assets one after another. Three limits keep a dive loading in reasonable time: only clips that could still become a Shaky Ghost are measured (`ShakeAnalysisPolicy`, which mirrors the classifier's earlier rules); a clip stops starting new windows after 1.0 s; and a dive spends at most 15 s in total (`ShakeBudget`). Clips beyond the budget are classified on the other signals, exactly as today.

**Priority.** A shaky clip becomes a Shaky Ghost *before* the brightness-based Framed Phantom check, but after the Flicker Wraith check (strobing is a stronger, rarer signal).

**Thresholds are starting values.** They were chosen from synthetic footage, not from real clips. `docs/shake-calibration.md` (Task 7) is the protocol for checking them on a phone; plan on one round of adjustment.

## Verification environment

- **Linux harness:** needs Swift 6.2 or newer (`https://download.swift.org/swift-6.2.1-release/ubuntu2404/swift-6.2.1-RELEASE/swift-6.2.1-RELEASE-ubuntu24.04.tar.gz` for Ubuntu 24.04). Run `SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh --filter CameraMotionTests`.
- **Xcode:** `xcodebuild -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug -destination 'platform=iOS Simulator,name=<an iOS 18+ iPhone>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:PurgeQuestTests/<Suite> test`, or `tools/ci/xcode-test.sh`.
- **No Mac available:** push and read the "iOS Unit Tests" workflow on the pull request. Do not report an Xcode-only step as passed unless it ran.
- **Verified while writing this plan:** Tasks 1 to 4 were replayed from a clean copy on Swift 6.2.1 in the harness's settings and in the app's settings (Swift 5 mode, default main-actor isolation, approachable concurrency): 29 tests pass in both, and each red phase failed for the stated reason. Tasks 5 and 6 edit files that import Photos and AVFoundation; their edits were applied to the real files (each `old` text matched once) and syntax-checked, but **not compiled**. Treat the first Xcode build of Task 5 as the real check.
- **Not verifiable without a device:** whether the thresholds separate real tripod, pan and handheld clips, and the real decode cost. Task 7 covers both.

## Global Constraints

- iOS 18.0+ deployment target; Swift 5 language mode; the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Every type and function in `CameraMotion.swift` is `nonisolated`, because under those settings a plain `async` function would otherwise run on the main actor.
- Fully offline, no third-party dependencies (`tools/ci/repo_guard.py`). `Logger` (`os`) is fine; networking APIs are not.
- Files listed in `tools/swift_harness/run.sh` must be pure Foundation and must exist.
- New Swift files under `ios/PurgeQuest/` and `ios/PurgeQuestTests/` are picked up automatically. Do not edit `project.pbxproj`.
- Tests use Swift Testing; suites are `@MainActor`, as in `BestiaryTests.swift`. Keep expressions in tests simple (local constants): chained integer arithmetic inside initializer calls exceeds the type checker's budget under the app's settings.
- Commit messages are plain imperative sentences.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `ios/PurgeQuest/Services/CameraMotion.swift` | create | `GrayFrame`, block-matching estimator, `ShakeAnalyzer`, `ShakeSampling`, `ShakeAnalysisPolicy`, `ShakeBudget` (all pure) |
| `ios/PurgeQuestTests/CameraMotionTests.swift` | create | 29 pure tests, including synthetic footage end to end |
| `tools/swift_harness/run.sh` | modify | Run the above on Linux |
| `ios/PurgeQuest/Services/VideoFrameAnalysisService.swift` | modify | Decode frame runs, measure shake, expose `VideoFrameSignals.shake` |
| `ios/PurgeQuest/Services/PhotoLibraryService.swift` | modify | Apply the policy and the dive budget |
| `ios/PurgeQuest/Services/MonsterClassifier.swift` | modify | Summon the Shaky Ghost from measured shake |
| `ios/PurgeQuestTests/MonsterClassifierShakeTests.swift` | create | Classifier behaviour and policy/classifier agreement |
| `ios/PurgeQuestTests/VideoFrameAnalysisTests.swift` | create | Frame-to-grid conversion |
| `ios/PurgeQuestTests/BestiaryTests.swift` | modify | Replace the brightness-based shaky test |
| `ios/PurgeQuestTests/ContentReachabilityTests.swift` | modify (only if the content-reachability plan landed) | Shaky Ghost witness |
| `docs/shake-calibration.md` | create | How to tune the thresholds on real clips |
| `README.md` | modify | Shaky Ghost row and roadmap |

---

### Task 1: Grayscale frames and the block-matching estimator

**Files:**
- Create: `ios/PurgeQuest/Services/CameraMotion.swift`
- Create: `ios/PurgeQuestTests/CameraMotionTests.swift`
- Modify: `tools/swift_harness/run.sh`

**Interfaces:**
- Produces: `GrayFrame(width:height:pixels:)` (failable; nil unless `pixels.count == width * height`), `MotionEstimate(dx:dy:confidence:)`, `BlockMatchingMotionEstimator.estimate(from:to:searchRadius:) -> MotionEstimate?`. `dx` and `dy` are the picture's displacement from the first frame to the second, in pixels, right and down positive.

- [ ] **Step 1: Write the failing tests and register them**

Create `ios/PurgeQuestTests/CameraMotionTests.swift`:

```swift
//
//  CameraMotionTests.swift
//  PurgeQuestTests
//
//  Pure-Foundation tests for the Shaky Ghost's motion math. They also run on the Linux harness
//  (tools/swift_harness/run.sh), so nothing here may touch UIKit, AVFoundation or Photos.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct CameraMotionTests {

    // MARK: - Test pictures

    /// Deterministic pseudo-random numbers in 0..<1 (SplitMix64).
    private struct Noise {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return Double(z ^ (z >> 31)) / Double(UInt64.max)
        }
    }

    /// A smooth picture with detail at two scales, bigger than any frame cut from it.
    private struct Scene {
        static let width = 260
        static let height = 200
        private let values: [Double]

        init(seed: UInt64) {
            var noise = Noise(seed: seed)
            let coarse = Scene.lattice(columns: 18, rows: 14, noise: &noise)
            let fine = Scene.lattice(columns: 66, rows: 50, noise: &noise)
            var values = [Double](repeating: 0, count: Scene.width * Scene.height)
            for y in 0..<Scene.height {
                for x in 0..<Scene.width {
                    let big = Scene.bilinear(coarse, x: Double(x) / Double(Scene.width - 1), y: Double(y) / Double(Scene.height - 1))
                    let small = Scene.bilinear(fine, x: Double(x) / Double(Scene.width - 1), y: Double(y) / Double(Scene.height - 1))
                    values[y * Scene.width + x] = 40 + 120 * big + 50 * small
                }
            }
            self.values = values
        }

        /// The picture's luminance at a fractional position (bilinear, clamped to the edges).
        func sample(x: Double, y: Double) -> Double {
            let cx = min(max(x, 0), Double(Scene.width - 1))
            let cy = min(max(y, 0), Double(Scene.height - 1))
            let x0 = Int(cx), y0 = Int(cy)
            let x1 = min(x0 + 1, Scene.width - 1), y1 = min(y0 + 1, Scene.height - 1)
            let fx = cx - Double(x0), fy = cy - Double(y0)
            let top = values[y0 * Scene.width + x0] * (1 - fx) + values[y0 * Scene.width + x1] * fx
            let bottom = values[y1 * Scene.width + x0] * (1 - fx) + values[y1 * Scene.width + x1] * fx
            return top * (1 - fy) + bottom * fy
        }

        private static func lattice(columns: Int, rows: Int, noise: inout Noise) -> (columns: Int, rows: Int, values: [Double]) {
            var values: [Double] = []
            for _ in 0..<(columns * rows) { values.append(noise.next()) }
            return (columns, rows, values)
        }

        private static func bilinear(_ grid: (columns: Int, rows: Int, values: [Double]), x: Double, y: Double) -> Double {
            let gx = x * Double(grid.columns - 1)
            let gy = y * Double(grid.rows - 1)
            let x0 = min(Int(gx), grid.columns - 2), y0 = min(Int(gy), grid.rows - 2)
            let fx = gx - Double(x0), fy = gy - Double(y0)
            let v00 = grid.values[y0 * grid.columns + x0], v10 = grid.values[y0 * grid.columns + x0 + 1]
            let v01 = grid.values[(y0 + 1) * grid.columns + x0], v11 = grid.values[(y0 + 1) * grid.columns + x0 + 1]
            return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy
        }
    }

    /// A 120×80 frame cut from `scene` with its top-left corner at (originX, originY).
    private func frame(_ scene: Scene, originX: Double, originY: Double, grain: Double = 0, seed: UInt64 = 7) -> GrayFrame {
        var noise = Noise(seed: seed)
        var pixels: [UInt8] = []
        for y in 0..<80 {
            for x in 0..<120 {
                var value = scene.sample(x: originX + Double(x), y: originY + Double(y))
                if grain > 0 { value += (noise.next() - 0.5) * 2 * grain }
                pixels.append(UInt8(max(0, min(255, value.rounded()))))
            }
        }
        return GrayFrame(width: 120, height: 80, pixels: pixels)!
    }

    /// Two frames in which the picture moves by (dx, dy) pixels.
    private func pair(_ scene: Scene, contentMovesBy dx: Double, _ dy: Double, grain: Double = 0) -> (GrayFrame, GrayFrame) {
        (frame(scene, originX: 70, originY: 60, grain: grain, seed: 1),
         frame(scene, originX: 70 - dx, originY: 60 - dy, grain: grain, seed: 2))
    }

    // MARK: - GrayFrame

    @Test func grayFrameNeedsExactlyWidthTimesHeightSamples() {
        #expect(GrayFrame(width: 4, height: 3, pixels: [UInt8](repeating: 0, count: 12)) != nil)
        #expect(GrayFrame(width: 4, height: 3, pixels: [UInt8](repeating: 0, count: 11)) == nil)
        #expect(GrayFrame(width: 0, height: 3, pixels: []) == nil)
    }

    // MARK: - Block matching

    @Test func identicalFramesMeanNoMotion() throws {
        let scene = Scene(seed: 11)
        let (a, b) = pair(scene, contentMovesBy: 0, 0)
        let estimate = try #require(BlockMatchingMotionEstimator.estimate(from: a, to: b))
        #expect(abs(estimate.dx) < 0.05)
        #expect(abs(estimate.dy) < 0.05)
        #expect(estimate.confidence > 0.8)
    }

    @Test func wholePixelMotionIsRecoveredInEveryDirection() throws {
        let scene = Scene(seed: 11)
        for (dx, dy) in [(3.0, -2.0), (-5.0, 4.0), (7.0, 0.0), (0.0, -7.0)] {
            let (a, b) = pair(scene, contentMovesBy: dx, dy)
            let estimate = try #require(BlockMatchingMotionEstimator.estimate(from: a, to: b), "no estimate for \(dx), \(dy)")
            #expect(abs(estimate.dx - dx) < 0.1, "dx \(estimate.dx) for \(dx)")
            #expect(abs(estimate.dy - dy) < 0.1, "dy \(estimate.dy) for \(dy)")
        }
    }

    @Test func subPixelMotionIsRecoveredWithinAThirdOfAPixel() throws {
        let scene = Scene(seed: 23)
        for (dx, dy) in [(1.5, 0.5), (-2.25, 1.75), (0.4, -0.6)] {
            let (a, b) = pair(scene, contentMovesBy: dx, dy)
            let estimate = try #require(BlockMatchingMotionEstimator.estimate(from: a, to: b), "no estimate for \(dx), \(dy)")
            #expect(abs(estimate.dx - dx) < 0.33, "dx \(estimate.dx) for \(dx)")
            #expect(abs(estimate.dy - dy) < 0.33, "dy \(estimate.dy) for \(dy)")
        }
    }

    @Test func sensorGrainDoesNotThrowTheMatchOff() throws {
        let scene = Scene(seed: 31)
        let (a, b) = pair(scene, contentMovesBy: 4, -3, grain: 3)
        let estimate = try #require(BlockMatchingMotionEstimator.estimate(from: a, to: b))
        #expect(abs(estimate.dx - 4) < 0.33)
        #expect(abs(estimate.dy + 3) < 0.33)
    }

    @Test func unrelatedFramesAreRejectedAsACut() {
        let a = frame(Scene(seed: 41), originX: 70, originY: 60)
        let b = frame(Scene(seed: 42), originX: 70, originY: 60)
        #expect(BlockMatchingMotionEstimator.estimate(from: a, to: b) == nil)
    }

    @Test func flatFramesAreRejected() {
        let flat = GrayFrame(width: 120, height: 80, pixels: [UInt8](repeating: 128, count: 120 * 80))!
        #expect(BlockMatchingMotionEstimator.estimate(from: flat, to: flat) == nil)
    }

    @Test func motionBeyondTheSearchWindowIsRejected() {
        let scene = Scene(seed: 11)
        let (a, b) = pair(scene, contentMovesBy: 14, 0)
        #expect(BlockMatchingMotionEstimator.estimate(from: a, to: b) == nil)
    }

    @Test func framesOfDifferentSizesAreRejected() {
        let scene = Scene(seed: 11)
        let a = frame(scene, originX: 70, originY: 60)
        let small = GrayFrame(width: 60, height: 40, pixels: [UInt8](repeating: 9, count: 60 * 40))!
        #expect(BlockMatchingMotionEstimator.estimate(from: a, to: small) == nil)
    }

    // New tests go above this line.
}
```

Create `ios/PurgeQuest/Services/CameraMotion.swift` containing only:

```swift
import Foundation
```

In `tools/swift_harness/run.sh` make three one-token additions. Each `old` text occurs once:

```text
Models/ColorTheme
```

becomes

```text
Models/ColorTheme Services/CameraMotion
```

```text
ThemePaletteTests
```

becomes

```text
ThemePaletteTests CameraMotionTests
```

and in the header comment

```text
AppearanceMode, ColorTheme
```

becomes

```text
AppearanceMode, ColorTheme, CameraMotion
```

If the duplicate-detection or Core ML plans have already landed, the same lines also name their files; append yours, the order does not matter.

- [ ] **Step 2: Run them and confirm they fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: FAIL to compile with `cannot find type 'GrayFrame' in scope`.

- [ ] **Step 3: Write the estimator**

Replace the contents of `ios/PurgeQuest/Services/CameraMotion.swift` with:

```swift
//
//  CameraMotion.swift
//  PurgeQuest
//
//  Camera-shake math for the Shaky Ghost. VideoFrameAnalysisService decodes a few short runs of
//  small grayscale frames; everything in this file is deterministic Foundation code, so it is
//  unit-tested on Linux (tools/swift_harness) as well as in Xcode.
//
//    GrayFrame                      a tiny luminance image
//    BlockMatchingMotionEstimator   how far the picture moved between two frames (sub-pixel)
//    ShakeAnalyzer                  how jittery a run of those moves is
//    ShakeSampling / ShakeAnalysisPolicy   where to sample, and which clips are worth the work
//
//  Every type is `nonisolated`: the app module defaults to the main actor, and this work belongs
//  on a background thread.
//

import Foundation

/// A small 8-bit luminance image, row-major, top row first.
nonisolated struct GrayFrame: Sendable, Equatable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    /// Nil unless `pixels` holds exactly `width × height` samples.
    init?(width: Int, height: Int, pixels: [UInt8]) {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

/// Where the picture moved between two frames, in frame pixels.
nonisolated struct MotionEstimate: Sendable, Equatable {
    /// Displacement of the picture from the first frame to the second (right and down are positive).
    let dx: Double
    let dy: Double
    /// How decisive the match was, 0…1 (1 = unmistakable).
    let confidence: Double
}

/// Finds the global translation between two frames by trying every whole-pixel shift in a small
/// window, keeping the one with the smallest mean absolute difference, and refining it to a
/// fraction of a pixel with a parabola through the neighbouring costs.
nonisolated enum BlockMatchingMotionEstimator {

    /// Largest whole-pixel shift tried in each direction.
    static let defaultSearchRadius = 8
    /// A frame flatter than this (mean absolute neighbour difference, in gray levels) has nothing to match.
    static let minimumTexture = 2.0
    /// The best shift must beat the average candidate by this fraction, or the match is a guess.
    static let minimumConfidence = 0.2

    /// Nil when the frames differ in size, are too flat, do not resemble each other (a cut), or
    /// the best match sits on the edge of the search window (the picture moved further than we look).
    static func estimate(
        from a: GrayFrame,
        to b: GrayFrame,
        searchRadius radius: Int = defaultSearchRadius
    ) -> MotionEstimate? {
        guard a.width == b.width, a.height == b.height, radius > 0,
              a.width > 4 * radius, a.height > 4 * radius else { return nil }
        guard texture(of: a, margin: radius) >= minimumTexture else { return nil }

        let side = 2 * radius + 1
        var cost = [Double](repeating: 0, count: side * side)   // index (shiftY + r) * side + (shiftX + r)
        var best = Double.infinity
        var bestIndex = 0
        var total = 0.0
        for shiftY in -radius...radius {
            for shiftX in -radius...radius {
                let c = meanAbsoluteDifference(a, b, shiftX: shiftX, shiftY: shiftY, margin: radius)
                let index = (shiftY + radius) * side + (shiftX + radius)
                cost[index] = c
                total += c
                if c < best {            // strict: the first minimum wins, so ties are deterministic
                    best = c
                    bestIndex = index
                }
            }
        }
        let mean = total / Double(side * side)
        guard mean > 0 else { return nil }
        let confidence = 1 - best / mean
        guard confidence >= minimumConfidence else { return nil }

        let column = bestIndex % side
        let row = bestIndex / side
        guard column > 0, column < side - 1, row > 0, row < side - 1 else { return nil }

        let centre = cost[bestIndex]
        let dx = Double(column - radius) + parabolicOffset(cost[bestIndex - 1], centre, cost[bestIndex + 1])
        let dy = Double(row - radius) + parabolicOffset(cost[bestIndex - side], centre, cost[bestIndex + side])
        return MotionEstimate(dx: dx, dy: dy, confidence: confidence)
    }

    /// Mean |a(x, y) − b(x + shiftX, y + shiftY)| over the central window. The window leaves a
    /// `margin` border on every side so that each candidate shift compares the same pixel count.
    private static func meanAbsoluteDifference(
        _ a: GrayFrame, _ b: GrayFrame, shiftX: Int, shiftY: Int, margin: Int
    ) -> Double {
        let width = a.width
        var total = 0
        var count = 0
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                for y in margin..<(a.height - margin) {
                    let rowA = y * width
                    let rowB = (y + shiftY) * width + shiftX
                    for x in margin..<(width - margin) {
                        total += abs(Int(pa[rowA + x]) - Int(pb[rowB + x]))
                    }
                    count += width - 2 * margin
                }
            }
        }
        return count == 0 ? 0 : Double(total) / Double(count)
    }

    /// Mean absolute difference between neighbouring pixels in the central window.
    private static func texture(of frame: GrayFrame, margin: Int) -> Double {
        let width = frame.width
        var total = 0
        var count = 0
        frame.pixels.withUnsafeBufferPointer { p in
            for y in margin..<(frame.height - margin - 1) {
                for x in margin..<(width - margin - 1) {
                    let i = y * width + x
                    let centre = Int(p[i])
                    total += abs(Int(p[i + 1]) - centre) + abs(Int(p[i + width]) - centre)
                    count += 2
                }
            }
        }
        return count == 0 ? 0 : Double(total) / Double(count)
    }

    /// Offset (−0.5…0.5) of the minimum of the parabola through three equally spaced costs.
    private static func parabolicOffset(_ minus: Double, _ centre: Double, _ plus: Double) -> Double {
        let curvature = minus - 2 * centre + plus
        guard curvature > 1e-9 else { return 0 }
        return max(-0.5, min(0.5, 0.5 * (minus - plus) / curvature))
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: PASS, nine tests: identical frames read as no motion; whole-pixel motion in all four directions is recovered; sub-pixel motion is recovered within a third of a pixel (0.2 % of a 160 px frame, far below the shake threshold); sensor grain does not matter; unrelated frames, flat frames, oversized motion and mismatched sizes are refused.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/CameraMotion.swift ios/PurgeQuestTests/CameraMotionTests.swift tools/swift_harness/run.sh
git commit -m "Measure the motion between two video frames by block matching"
```

---

### Task 2: Judge how much a run of moves jitters

**Files:**
- Modify: `ios/PurgeQuest/Services/CameraMotion.swift`
- Modify: `ios/PurgeQuestTests/CameraMotionTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1 (the analyzer takes plain numbers).
- Produces: `MotionSample(dx:dy:)`; `ShakeSignals(jitter:reversalRatio:sampleCount:)` with `isShaky` and the constants `jitterThreshold` (0.010), `reversalThreshold` (0.3), `minimumSamples` (6); `ShakeAnalyzer.evaluate(runs: [[MotionSample?]], frameLongEdge: Double) -> ShakeSignals?`.

- [ ] **Step 1: Add the failing tests**

Insert immediately above the line `    // New tests go above this line.` in `CameraMotionTests.swift`:

```swift
    // MARK: - Shake analysis

    /// Successive moves along x, one per sample.
    private func run(_ dxs: [Double]) -> [MotionSample?] {
        dxs.map { MotionSample(dx: $0, dy: 0) }
    }

    @Test func aSteadyCameraIsNotShaky() throws {
        let still = run([Double](repeating: 0, count: 6))
        let signals = try #require(ShakeAnalyzer.evaluate(runs: [still], frameLongEdge: 160))
        #expect(signals.jitter == 0)
        #expect(signals.reversalRatio == 0)
        #expect(!signals.isShaky)
    }

    @Test func aSteadyPanIsNotShaky() throws {
        // Constant velocity: the camera moves a lot but never changes its mind.
        let right = run([Double](repeating: 3, count: 6))
        let left = run([Double](repeating: -3, count: 6))
        let signals = try #require(ShakeAnalyzer.evaluate(runs: [right, left], frameLongEdge: 160))
        #expect(signals.jitter < 0.0001)
        #expect(!signals.isShaky)
    }

    @Test func aPanThatEasesInAndOutIsNotShaky() throws {
        let eased = run([0.5, 1, 2, 3, 4, 4, 4, 3, 2, 1, 0.5])
        let signals = try #require(ShakeAnalyzer.evaluate(runs: [eased], frameLongEdge: 160))
        #expect(signals.jitter < ShakeSignals.jitterThreshold)
        #expect(!signals.isShaky)
    }

    @Test func aHandTremorIsShaky() throws {
        // Left and right by 1.6 px (1% of a 160 px frame) at every sample.
        let tremor = run([1.6, -1.6, 1.6, -1.6, 1.6, -1.6, 1.6])
        let signals = try #require(ShakeAnalyzer.evaluate(runs: [tremor, tremor], frameLongEdge: 160))
        #expect(signals.reversalRatio == 1)
        #expect(signals.jitter > ShakeSignals.jitterThreshold)
        #expect(signals.isShaky)
    }

    @Test func randomTremorInBothAxesIsShaky() throws {
        var noise = Noise(seed: 5)
        var runs: [[MotionSample?]] = []
        for _ in 0..<4 {
            var moves: [MotionSample?] = []
            for _ in 0..<6 {
                moves.append(MotionSample(dx: (noise.next() - 0.5) * 6, dy: (noise.next() - 0.5) * 6))
            }
            runs.append(moves)
        }
        let signals = try #require(ShakeAnalyzer.evaluate(runs: runs, frameLongEdge: 160))
        #expect(signals.isShaky, "jitter \(signals.jitter), reversals \(signals.reversalRatio)")
    }

    @Test func gapsRestartTheRun() {
        // Moves either side of a failed measurement are never compared with one another.
        let split: [MotionSample?] = [
            MotionSample(dx: 5, dy: 0), nil, MotionSample(dx: -5, dy: 0), nil, MotionSample(dx: 5, dy: 0)
        ]
        #expect(ShakeAnalyzer.evaluate(runs: [split], frameLongEdge: 160) == nil)
    }

    @Test func tooFewComparisonsIsNotAVerdict() throws {
        let short = run([4, -4, 4])
        let signals = try #require(ShakeAnalyzer.evaluate(runs: [short], frameLongEdge: 160))
        #expect(signals.sampleCount == 2)
        #expect(signals.jitter > ShakeSignals.jitterThreshold)
        #expect(!signals.isShaky)
    }

    @Test func jitterIsMeasuredRelativeToTheFrameSize() throws {
        let small = try #require(ShakeAnalyzer.evaluate(runs: [run([1.6, -1.6, 1.6, -1.6, 1.6, -1.6, 1.6])], frameLongEdge: 160))
        let large = try #require(ShakeAnalyzer.evaluate(runs: [run([3.2, -3.2, 3.2, -3.2, 3.2, -3.2, 3.2])], frameLongEdge: 320))
        #expect(abs(small.jitter - large.jitter) < 1e-12)
    }

    @Test func movesBelowTheNoiseFloorNeverCountAsReversals() throws {
        let wobble = run([0.1, -0.1, 0.1, -0.1, 0.1, -0.1, 0.1])
        let signals = try #require(ShakeAnalyzer.evaluate(runs: [wobble, wobble], frameLongEdge: 160))
        #expect(signals.reversalRatio == 0)
        #expect(!signals.isShaky)
    }

    @Test func nothingMeasuredMeansNoVerdict() {
        #expect(ShakeAnalyzer.evaluate(runs: [], frameLongEdge: 160) == nil)
        #expect(ShakeAnalyzer.evaluate(runs: [[nil, nil, nil]], frameLongEdge: 160) == nil)
        #expect(ShakeAnalyzer.evaluate(runs: [run([1, -1, 1])], frameLongEdge: 0) == nil)
    }
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: FAIL to compile with `cannot find type 'MotionSample' in scope` and `cannot find 'ShakeAnalyzer' in scope`.

- [ ] **Step 3: Append the analyzer**

Append to the end of `CameraMotion.swift`:

```swift

// MARK: - Shake analysis

/// One measured move between two consecutive frames, in frame pixels.
nonisolated struct MotionSample: Sendable, Equatable {
    let dx: Double
    let dy: Double
}

/// How shaky a clip's camera is.
nonisolated struct ShakeSignals: Sendable, Equatable {
    /// RMS change in camera velocity from one sample to the next, as a fraction of the frame's long edge.
    let jitter: Double
    /// Share of consecutive moves that reversed direction (a tremor reverses; a pan does not).
    let reversalRatio: Double
    /// How many pairs of consecutive moves the measurement rests on.
    let sampleCount: Int

    // Thresholds live here so the classifier, the analyzer and the tests share one source of truth.
    // They are starting values: calibrate them on real clips (docs/shake-calibration.md).
    static let jitterThreshold = 0.010
    static let reversalThreshold = 0.3
    static let minimumSamples = 6

    var isShaky: Bool {
        sampleCount >= Self.minimumSamples
            && jitter >= Self.jitterThreshold
            && reversalRatio >= Self.reversalThreshold
    }
}

nonisolated enum ShakeAnalyzer {

    /// A move smaller than this fraction of the frame's long edge is tripod-still noise: it counts
    /// neither as a direction nor as a reversal.
    static let noiseFloor = 0.0015

    /// `runs` holds, for each sampled window, the successive moves between consecutive frames
    /// (nil where a pair could not be measured). Jitter is measured inside a run, never across a gap.
    static func evaluate(runs: [[MotionSample?]], frameLongEdge: Double) -> ShakeSignals? {
        guard frameLongEdge > 0 else { return nil }
        var squaredChange = 0.0
        var pairs = 0
        var flips = 0
        var directional = 0
        for run in runs where run.count >= 2 {
            for i in 1..<run.count {
                guard let previous = run[i - 1], let current = run[i] else { continue }
                let changeX = (current.dx - previous.dx) / frameLongEdge
                let changeY = (current.dy - previous.dy) / frameLongEdge
                squaredChange += changeX * changeX + changeY * changeY
                pairs += 1

                let previousSize = hypot(previous.dx, previous.dy) / frameLongEdge
                let currentSize = hypot(current.dx, current.dy) / frameLongEdge
                if previousSize > noiseFloor, currentSize > noiseFloor {
                    directional += 1
                    if previous.dx * current.dx + previous.dy * current.dy < 0 { flips += 1 }
                }
            }
        }
        guard pairs > 0 else { return nil }
        // A random tremor of size s changes by √2·s between samples, so halve the energy and the
        // result reads as the tremor's own size. A steady pan does not change at all: it reads 0.
        let jitter = (squaredChange / Double(pairs) / 2).squareRoot()
        let reversals = directional == 0 ? 0 : Double(flips) / Double(directional)
        return ShakeSignals(jitter: jitter, reversalRatio: reversals, sampleCount: pairs)
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: PASS, 19 tests. A steady camera, a steady pan and a pan that eases in and out are not shaky; alternating and random tremor are; gaps in a run are never compared across; jitter is relative to the frame size; moves below the noise floor never count as reversals.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/CameraMotion.swift ios/PurgeQuestTests/CameraMotionTests.swift
git commit -m "Tell camera shake from steady panning by how the velocity changes"
```

---

### Task 3: Where to sample, which clips to measure, and how long to spend

**Files:**
- Modify: `ios/PurgeQuest/Services/CameraMotion.swift`
- Modify: `ios/PurgeQuestTests/CameraMotionTests.swift`

**Interfaces:**
- Produces: `ShakeSampling.framesPerWindow` (7), `.frameInterval` (0.1), `.windowSpan`, `.windowFractions` ([0.15, 0.45, 0.75]), `.timeBudget` (1.0 s per clip), `.diveBudget` (15 s), `.windowStarts(duration:) -> [Double]`, `.isEvenlySpaced(_:_:) -> Bool`; `ShakeAnalysisPolicy.shouldAnalyze(durationSeconds:bytes:longEdge:isScreenRecording:isLooping:isHighFrameRate:) -> Bool`; `ShakeBudget` (`remaining`, `allowsAnalysis`, `spend(_:)`).

- [ ] **Step 1: Add the failing tests**

Insert above `    // New tests go above this line.`:

```swift
    // MARK: - Sampling and policy

    @Test func windowsFitInsideTheClip() {
        for duration in [2.0, 2.5, 5.0, 30.0, 120.0] {
            let starts = ShakeSampling.windowStarts(duration: duration)
            #expect(!starts.isEmpty)
            #expect(starts == starts.sorted())
            #expect(Set(starts).count == starts.count)
            for start in starts {
                #expect(start >= 0)
                #expect(start + ShakeSampling.windowSpan <= duration, "window at \(start) overruns a \(duration) s clip")
            }
        }
        #expect(ShakeSampling.windowStarts(duration: 0).isEmpty)
        #expect(ShakeSampling.windowStarts(duration: .nan).isEmpty)
    }

    @Test func longClipsAreSampledAcrossTheirLength() {
        let starts = ShakeSampling.windowStarts(duration: 60)
        #expect(starts.count == ShakeSampling.windowFractions.count)
        #expect(abs(starts[0] - 9) < 1e-9)    // 15 %
        #expect(abs(starts[2] - 45) < 1e-9)   // 75 %
    }

    @Test func framesAboutOneIntervalApartAreEvenlySpaced() {
        #expect(ShakeSampling.isEvenlySpaced(1.00, 1.10))
        #expect(ShakeSampling.isEvenlySpaced(1.00, 1.14))
        #expect(!ShakeSampling.isEvenlySpaced(1.00, 1.00))   // the same frame twice
        #expect(!ShakeSampling.isEvenlySpaced(1.00, 1.30))   // a dropped stretch
    }

    @Test func onlyClipsThatCouldBeShakyGhostsAreAnalyzed() {
        func analyze(duration: Double = 30, bytes: Int64 = 80_000_000, longEdge: Int = 1920,
                     screen: Bool = false, looping: Bool = false, highFPS: Bool = false) -> Bool {
            ShakeAnalysisPolicy.shouldAnalyze(
                durationSeconds: duration, bytes: bytes, longEdge: longEdge,
                isScreenRecording: screen, isLooping: looping, isHighFrameRate: highFPS
            )
        }
        #expect(analyze())
        #expect(analyze(duration: 2))
        #expect(analyze(duration: 120))
        #expect(!analyze(duration: 1.9))
        #expect(!analyze(duration: 121))
        #expect(!analyze(bytes: 0))
        #expect(analyze(bytes: 499_999_999))
        #expect(!analyze(bytes: 500_000_000))
        #expect(analyze(longEdge: 3_839))
        #expect(!analyze(longEdge: 3_840))
        #expect(!analyze(screen: true))
        #expect(!analyze(looping: true))
        #expect(!analyze(highFPS: true))
    }

    @Test func theDiveBudgetRunsOut() {
        var budget = ShakeBudget(seconds: 2)
        #expect(budget.allowsAnalysis)
        budget.spend(0.75)
        #expect(budget.allowsAnalysis)
        budget.spend(1.25)
        #expect(!budget.allowsAnalysis)
        budget.spend(5)
        #expect(budget.remaining == 0)
        budget.spend(-1)
        #expect(budget.remaining == 0)
    }

    @Test func aFreshBudgetIsTheDiveBudget() {
        #expect(ShakeBudget().remaining == ShakeSampling.diveBudget)
        #expect(ShakeBudget(seconds: -3).remaining == 0)
    }
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: FAIL to compile with `cannot find 'ShakeSampling' in scope`.

- [ ] **Step 3: Append the sampling, policy and budget**

Append to the end of `CameraMotion.swift`:

```swift

// MARK: - Sampling and gating

/// Where and how densely a clip is sampled for camera motion.
nonisolated enum ShakeSampling {
    /// Frames decoded per window; consecutive frames are `frameInterval` seconds apart.
    static let framesPerWindow = 7
    static let frameInterval = 0.1
    /// Seconds from a window's first frame to its last.
    static var windowSpan: Double { Double(framesPerWindow - 1) * frameInterval }
    /// Where each window starts, as a fraction of the clip. The very start and end are skipped:
    /// that is where the camera is being raised or put down.
    static let windowFractions = [0.15, 0.45, 0.75]
    /// Decoding stops starting new windows on a clip after this long.
    static let timeBudget: TimeInterval = 1.0
    /// Total time one dive may spend measuring shake. Dives load their clips one after another,
    /// so without a cap a video-heavy library would add minutes to the loading screen.
    static let diveBudget: TimeInterval = 15

    /// Start times (seconds) of the windows for a clip, ascending, each leaving room for a whole window.
    static func windowStarts(duration: Double) -> [Double] {
        guard duration.isFinite, duration > 0 else { return [] }
        let latest = max(0, duration - windowSpan - 0.05)
        var starts: [Double] = []
        for fraction in windowFractions {
            let start = min(duration * fraction, latest)
            if starts.last.map({ start > $0 + 1e-9 }) ?? true { starts.append(start) }
        }
        return starts
    }

    /// True when two decoded frames are about one interval apart. A variable-frame-rate clip can
    /// hand back the same frame twice; such a pair says nothing about motion.
    static func isEvenlySpaced(_ previous: Double, _ current: Double) -> Bool {
        abs((current - previous) - frameInterval) <= frameInterval * 0.5
    }
}

/// Which clips are worth the decoding: only those the classifier could still call a Shaky Ghost.
/// It mirrors the rules in `MonsterClassifier.classifyVideo` that fire before motion is consulted;
/// `MonsterClassifierShakeTests` keeps the two in step.
nonisolated enum ShakeAnalysisPolicy {
    static let minimumDuration = 2.0
    static let maximumDuration = 120.0
    static let maximumBytes: Int64 = 500_000_000
    static let maximumLongEdge = 3_840

    static func shouldAnalyze(
        durationSeconds: Double,
        bytes: Int64,
        longEdge: Int,
        isScreenRecording: Bool,
        isLooping: Bool,
        isHighFrameRate: Bool
    ) -> Bool {
        durationSeconds >= minimumDuration && durationSeconds <= maximumDuration
            && bytes > 0 && bytes < maximumBytes
            && longEdge < maximumLongEdge
            && !isScreenRecording && !isLooping && !isHighFrameRate
    }
}

/// What is left of a dive's shake-measuring time. Clips beyond the budget simply go unmeasured and
/// are classified on the other signals, exactly as before.
nonisolated struct ShakeBudget: Sendable, Equatable {
    private(set) var remaining: TimeInterval

    init(seconds: TimeInterval = ShakeSampling.diveBudget) {
        remaining = max(0, seconds)
    }

    var allowsAnalysis: Bool { remaining > 0 }

    /// Records time spent; a negative reading (clock hiccup) never refills the budget.
    mutating func spend(_ seconds: TimeInterval) {
        remaining = max(0, remaining - max(0, seconds))
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: PASS, 25 tests.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/CameraMotion.swift ios/PurgeQuestTests/CameraMotionTests.swift
git commit -m "Choose where to sample for camera shake and cap the time it may take"
```

---

### Task 4: Run the whole pipeline over synthetic footage

**Files:**
- Modify: `ios/PurgeQuestTests/CameraMotionTests.swift`

These tests exercise Tasks 1 and 2 together, the place where a calibration mistake would hide, so they should pass on the first run.

- [ ] **Step 1: Add the tests**

Insert above `    // New tests go above this line.`:

```swift
    // MARK: - Whole pipeline on synthetic footage

    /// Cuts 7 frames per window from one scene along a camera path, measures the move between each
    /// pair of neighbours, and judges the result: exactly what the app does with decoded video.
    private func verdict(cameraPath path: [(x: Double, y: Double)], windows: Int = 3) -> ShakeSignals? {
        let scene = Scene(seed: 99)
        var runs: [[MotionSample?]] = []
        for w in 0..<windows {
            var frames: [GrayFrame] = []
            for k in 0..<7 {
                let position = path[w * 7 + k]
                frames.append(frame(scene, originX: 70 + position.x, originY: 60 + position.y, seed: 3))
            }
            var moves: [MotionSample?] = []
            for k in 1..<frames.count {
                let estimate = BlockMatchingMotionEstimator.estimate(from: frames[k - 1], to: frames[k])
                moves.append(estimate.map { MotionSample(dx: $0.dx, dy: $0.dy) })
            }
            runs.append(moves)
        }
        return ShakeAnalyzer.evaluate(runs: runs, frameLongEdge: 120)
    }

    private func path(_ position: (Int) -> (x: Double, y: Double)) -> [(x: Double, y: Double)] {
        (0..<21).map(position)
    }

    @Test func footageFromATripodIsNotShaky() throws {
        let signals = try #require(verdict(cameraPath: path { _ in (0, 0) }))
        #expect(signals.jitter < 0.002)
        #expect(!signals.isShaky)
    }

    @Test func footageOfASteadyPanIsNotShaky() throws {
        let signals = try #require(verdict(cameraPath: path { i in (Double(i % 7) * 1.5, 0) }))
        #expect(signals.jitter < ShakeSignals.jitterThreshold)
        #expect(!signals.isShaky)
    }

    @Test func footageFromAShakingHandIsShaky() throws {
        let signals = try #require(verdict(cameraPath: path { i in (i % 2 == 0 ? 0 : 1.8, i % 3 == 0 ? 0.6 : 0) }))
        #expect(signals.isShaky, "jitter \(signals.jitter), reversals \(signals.reversalRatio), samples \(signals.sampleCount)")
    }

    @Test func aMildWobbleBelowTheThresholdIsLeftAlone() throws {
        // A stabilised phone held by a calm hand: about 0.4 px (0.3 % of the frame) of tremor.
        let signals = try #require(verdict(cameraPath: path { i in (i % 2 == 0 ? 0 : 0.4, 0) }))
        #expect(signals.jitter < ShakeSignals.jitterThreshold)
        #expect(!signals.isShaky)
    }
```

- [ ] **Step 2: Run them**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests`
Expected: PASS, 29 tests: a tripod and a steady pan are not shaky; a shaking hand (1.8 px alternating on a 120 px frame, 1.5 % of the long edge) is; a calm 0.4 px wobble (0.3 %) is left alone.

If `footageFromAShakingHandIsShaky` fails, read the numbers in its failure message before changing a threshold: a low `sampleCount` means the estimator refused many pairs (look at Task 1), a low `reversalRatio` or `jitter` means the thresholds do not suit the synthetic path.

- [ ] **Step 3: Commit**

```bash
git add ios/PurgeQuestTests/CameraMotionTests.swift
git commit -m "Test the shake pipeline end to end on synthetic footage"
```

---

### Task 5: Decode the frame runs and measure real videos

**Files:**
- Modify: `ios/PurgeQuest/Services/VideoFrameAnalysisService.swift`
- Modify: `ios/PurgeQuest/Services/PhotoLibraryService.swift`
- Create: `ios/PurgeQuestTests/VideoFrameAnalysisTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1 to 3.
- Produces: `VideoFrameSignals.shake: ShakeSignals?` and `VideoFrameSignals.isShaky`; `VideoFrameAnalysisService.signals(for:analyzeMotion:)`; `VideoFrameAnalysisService.grayFrame(from: CGImage) -> GrayFrame?`.

This task leaves `isErratic` in place: the classifier still uses it until Task 6, so the build stays green between tasks.

- [ ] **Step 1: Write the failing test**

Create `ios/PurgeQuestTests/VideoFrameAnalysisTests.swift`:

```swift
//
//  VideoFrameAnalysisTests.swift
//  PurgeQuestTests
//
//  The platform half of the shake pipeline that can run without a video file: turning a decoded
//  frame into the grayscale grid the motion math consumes.
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct VideoFrameAnalysisTests {

    @Test func grayFramesKeepTheirSizeAndBrightnessOrder() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: format)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
            UIColor.white.setFill()
            context.fill(CGRect(x: 20, y: 0, width: 20, height: 20))
        }
        let cgImage = try #require(image.cgImage)
        let frame = try #require(VideoFrameAnalysisService.grayFrame(from: cgImage))

        #expect(frame.width == 40)
        #expect(frame.height == 20)
        let row = frame.height / 2
        let black = Int(frame.pixels[row * frame.width + 5])
        let white = Int(frame.pixels[row * frame.width + 35])
        #expect(black < 30)
        #expect(white > 225)
    }
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `xcodebuild … -only-testing:PurgeQuestTests/VideoFrameAnalysisTests test`
Expected: FAIL to compile with `type 'VideoFrameAnalysisService' has no member 'grayFrame'`.

- [ ] **Step 3: Teach the signals about shake**

Apply these edits to `ios/PurgeQuest/Services/VideoFrameAnalysisService.swift`. Each `old` text occurs once.

3a. Import `os` for the calibration log line. Replace:

```swift
import CoreGraphics

/// Aggregated sampled-frame signals for one video.
```

with:

```swift
import CoreGraphics
import os

/// Aggregated sampled-frame signals for one video.
```

3b. Add the signal. Replace:

```swift
    /// Frames at or below the dark-luminance threshold.
    let darkFrameCount: Int

    var darkFrameRatio: Double { frameCount == 0 ? 0 : Double(darkFrameCount) / Double(frameCount) }
```

with:

```swift
    /// Frames at or below the dark-luminance threshold.
    let darkFrameCount: Int
    /// Camera shake measured from short runs of consecutive frames. Nil when the clip was not
    /// worth the decoding (see `ShakeAnalysisPolicy`) or too little could be measured.
    var shake: ShakeSignals? = nil

    var darkFrameRatio: Double { frameCount == 0 ? 0 : Double(darkFrameCount) / Double(frameCount) }
```

3c. Add `isShaky` beside `isErratic`. Replace:

```swift
    /// Unsteady handheld motion.
    var isErratic: Bool { meanMotion >= Self.erraticMotionThreshold }
```

with:

```swift
    /// Unsteady handheld motion.
    var isErratic: Bool { meanMotion >= Self.erraticMotionThreshold }
    /// Unsteady handheld motion, measured from the picture itself rather than from brightness.
    var isShaky: Bool { shake?.isShaky == true }
```

3d. Add the frame size and logger. Replace:

```swift
    static let maximumSampleSize = CGSize(width: 128, height: 128)
```

with:

```swift
    static let maximumSampleSize = CGSize(width: 128, height: 128)
    /// Frames for motion matching: 160 px on the long edge keeps one pixel near 0.6 % of the picture.
    nonisolated static let motionFrameSize = CGSize(width: 160, height: 160)
    nonisolated private static let log = Logger(subsystem: "PurgeQuest", category: "Shake")
```

3e. Let callers ask for motion. Replace:

```swift
    /// failures as a Glitchborn signal instead).
    static func signals(for asset: PHAsset) async -> VideoFrameSignals? {
```

with:

```swift
    /// failures as a Glitchborn signal instead). With `analyzeMotion` it also measures camera shake.
    static func signals(for asset: PHAsset, analyzeMotion: Bool = false) async -> VideoFrameSignals? {
```

3f. Measure shake after the brightness frames, off the main actor, and add the decoding and conversion code. Replace the end of `signals(for:)`:

```swift
            luminances.append(MLAnalysisService.averageLuminance(cgImage: image))
        }
        return VideoFrameSignals.evaluate(luminances: luminances)
    }
}
```

with:

```swift
            luminances.append(MLAnalysisService.averageLuminance(cgImage: image))
        }
        guard var signals = VideoFrameSignals.evaluate(luminances: luminances) else { return nil }
        if analyzeMotion {
            // Decoding and block matching are real work: keep them off the main actor.
            let clip = item.asset
            signals.shake = await Task.detached(priority: .utility) {
                await measureShake(in: clip, duration: seconds)
            }.value
        }
        return signals
    }

    // MARK: - Camera shake

    /// Decodes a few short runs of consecutive small frames and measures how much the camera
    /// jitters. Nil when too little could be measured to judge.
    nonisolated private static func measureShake(in asset: AVAsset, duration seconds: Double) async -> ShakeSignals? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = motionFrameSize
        // Exact frames: a tolerance would snap neighbouring requests onto the same keyframe.
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let started = Date()
        var runs: [[MotionSample?]] = []
        var longEdge = 0.0

        for start in ShakeSampling.windowStarts(duration: seconds) {
            if Date().timeIntervalSince(started) > ShakeSampling.timeBudget { break }

            var decoded: [(frame: GrayFrame, time: Double)?] = []
            for k in 0..<ShakeSampling.framesPerWindow {
                let requested = start + Double(k) * ShakeSampling.frameInterval
                guard requested < seconds,
                      let (image, actualTime) = try? await generator.image(at: CMTime(seconds: requested, preferredTimescale: 600)),
                      let gray = grayFrame(from: image) else {
                    decoded.append(nil)
                    continue
                }
                longEdge = Double(max(gray.width, gray.height))
                decoded.append((gray, actualTime.seconds))
            }

            var moves: [MotionSample?] = []
            for k in 1..<decoded.count {
                guard let previous = decoded[k - 1], let current = decoded[k],
                      ShakeSampling.isEvenlySpaced(previous.time, current.time),
                      let estimate = BlockMatchingMotionEstimator.estimate(from: previous.frame, to: current.frame) else {
                    moves.append(nil)
                    continue
                }
                moves.append(MotionSample(dx: estimate.dx, dy: estimate.dy))
            }
            runs.append(moves)
        }

        let signals = ShakeAnalyzer.evaluate(runs: runs, frameLongEdge: longEdge)
        if let signals {
            log.debug("shake jitter \(signals.jitter, format: .fixed(precision: 4)) reversals \(signals.reversalRatio, format: .fixed(precision: 2)) samples \(signals.sampleCount) shaky \(signals.isShaky)")
        }
        return signals
    }

    /// Converts a decoded frame to 8-bit luminance at its own size.
    nonisolated static func grayFrame(from image: CGImage) -> GrayFrame? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? GrayFrame(width: width, height: height, pixels: pixels) : nil
    }
}
```

Notes on that code: `Task.detached` is used because the repository already does (`StoreKitService`), it works whatever the build's isolation settings, and `@concurrent` would need the newest compiler. Frames are requested with zero time tolerance, because a tolerance snaps neighbouring requests onto the same keyframe and every motion reads as zero. Each pair is checked with `ShakeSampling.isEvenlySpaced`, because a variable-frame-rate clip can return the same frame twice.

- [ ] **Step 4: Apply the policy and the dive budget**

In `ios/PurgeQuest/Services/PhotoLibraryService.swift`, in `buildMediaItems`, replace:

```swift
        for asset in assets {
            let bytes = estimateBytes(for: asset)
            let thumb = withThumbnails ? await requestThumbnail(for: asset, size: thumbSize) : nil
```

with:

```swift
        var motionBudget = ShakeBudget()
        for asset in assets {
            let bytes = estimateBytes(for: asset)
            let thumb = withThumbnails ? await requestThumbnail(for: asset, size: thumbSize) : nil
```

and replace:

```swift
            if withThumbnails, asset.mediaType == .video, asset.duration > 0 {
                frames = await VideoFrameAnalysisService.signals(for: asset)
            }
```

with:

```swift
            if withThumbnails, asset.mediaType == .video, asset.duration > 0 {
                // Camera shake means decoding dozens of frames, so only clips that could still
                // become a Shaky Ghost are measured, and only while the dive's budget lasts.
                let analyzeMotion = motionBudget.allowsAnalysis && ShakeAnalysisPolicy.shouldAnalyze(
                    durationSeconds: asset.duration,
                    bytes: bytes,
                    longEdge: max(asset.pixelWidth, asset.pixelHeight),
                    isScreenRecording: signals.isScreenRecording,
                    isLooping: signals.isLooping,
                    isHighFrameRate: signals.isHighFrameRate
                )
                let began = Date()
                frames = await VideoFrameAnalysisService.signals(for: asset, analyzeMotion: analyzeMotion)
                if analyzeMotion { motionBudget.spend(Date().timeIntervalSince(began)) }
            }
```

- [ ] **Step 5: Build and run the tests**

Run: `xcodebuild … -only-testing:PurgeQuestTests/VideoFrameAnalysisTests test`, then `tools/ci/xcode-test.sh`.
Expected: PASS. If the compiler objects to passing a non-`Sendable` `AVAsset` into `Task.detached`, the project is in Swift 5 mode so it should only warn; do not silence it with a global setting, wrap the asset in a small `@unchecked Sendable` box as `BlurModelHandle` does in the Core ML plan.

- [ ] **Step 6: Commit**

```bash
git add ios/PurgeQuest/Services/VideoFrameAnalysisService.swift ios/PurgeQuest/Services/PhotoLibraryService.swift ios/PurgeQuestTests/VideoFrameAnalysisTests.swift
git commit -m "Measure camera shake on eligible videos within a time budget"
```

---

### Task 6: Summon the Shaky Ghost from measured shake

**Files:**
- Modify: `ios/PurgeQuest/Services/MonsterClassifier.swift`
- Modify: `ios/PurgeQuest/Services/VideoFrameAnalysisService.swift`
- Modify: `ios/PurgeQuestTests/BestiaryTests.swift`
- Create: `ios/PurgeQuestTests/MonsterClassifierShakeTests.swift`
- Modify (only if it exists): `ios/PurgeQuestTests/ContentReachabilityTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/MonsterClassifierShakeTests.swift`:

```swift
//
//  MonsterClassifierShakeTests.swift
//  PurgeQuestTests
//
//  The Shaky Ghost is summoned by measured camera shake, and the analysis policy only spends
//  decoding time on clips the classifier could still turn into one.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct MonsterClassifierShakeTests {

    private func video(
        duration: Double = 30, bytes: Int64 = 80_000_000, width: Int = 1920, height: Int = 1080,
        screen: Bool = false, looping: Bool = false, highFPS: Bool = false
    ) -> MediaItem {
        MediaItem(
            id: "v", kind: .video, creationDate: Date(), pixelWidth: width, pixelHeight: height,
            durationSeconds: duration, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenRecording: screen, isLooping: looping, isHighFrameRate: highFPS
        )
    }

    private func monster(_ item: MediaItem, frames: VideoFrameSignals?) -> MonsterType {
        var item = item
        item.frameSignals = frames
        return MonsterClassifier.classifySolo(item).monsterType
    }

    /// Brightness varies a little (not still, not strobing, not dark) and the camera shakes.
    private static var shakyFrames: VideoFrameSignals {
        var frames = VideoFrameSignals.evaluate(luminances: [0.5, 0.56, 0.5])!
        frames.shake = ShakeSignals(jitter: 0.02, reversalRatio: 0.6, sampleCount: 15)
        return frames
    }

    @Test func measuredShakeSummonsAShakyGhost() {
        #expect(monster(video(), frames: Self.shakyFrames) == .shakyGhost)
    }

    @Test func aSteadyClipIsNotAShakyGhost() {
        var steady = VideoFrameSignals.evaluate(luminances: [0.5, 0.56, 0.5])!
        steady.shake = ShakeSignals(jitter: 0.001, reversalRatio: 0, sampleCount: 15)
        #expect(monster(video(), frames: steady) != .shakyGhost)
    }

    @Test func brightnessSwingsAloneAreNotShake() {
        // The old luminance-only signal fired on any scene change; only measured motion counts now.
        let swingy = VideoFrameSignals.evaluate(luminances: [0.3, 0.5, 0.35])
        #expect(monster(video(), frames: swingy) != .shakyGhost)
    }

    @Test func shakeOutranksTheBrightnessBasedStillGuess() {
        var stillScene = VideoFrameSignals.evaluate(luminances: [0.5, 0.501, 0.502])!
        #expect(stillScene.isStatic)
        #expect(monster(video(), frames: stillScene) == .framedPhantom)
        stillScene.shake = ShakeSignals(jitter: 0.02, reversalRatio: 0.6, sampleCount: 15)
        #expect(monster(video(), frames: stillScene) == .shakyGhost)
    }

    @Test func flickerStillOutranksShake() {
        var strobing = VideoFrameSignals.evaluate(luminances: [0.2, 0.9, 0.15])!
        strobing.shake = ShakeSignals(jitter: 0.02, reversalRatio: 0.6, sampleCount: 15)
        #expect(monster(video(), frames: strobing) == .flickerWraith)
    }

    /// The policy and the classifier must agree: a clip is measured exactly when, with shaky
    /// footage, the classifier would call it a Shaky Ghost. (Clips under two seconds are the one
    /// deliberate gap, so the grid starts at two.)
    @Test func policyAndClassifierAgreeAcrossTheBoundaries() {
        let durations: [Double] = [2, 30, 120, 121]
        let sizes: [Int64] = [1_000, 499_999_999, 500_000_000]
        let edges: [(Int, Int)] = [(1920, 1080), (3839, 2160), (3840, 2160)]
        for duration in durations {
            for bytes in sizes {
                for (width, height) in edges {
                    for flag in 0..<4 {
                        let item = video(duration: duration, bytes: bytes, width: width, height: height,
                                         screen: flag == 1, looping: flag == 2, highFPS: flag == 3)
                        let measured = ShakeAnalysisPolicy.shouldAnalyze(
                            durationSeconds: duration, bytes: bytes, longEdge: max(width, height),
                            isScreenRecording: flag == 1, isLooping: flag == 2, isHighFrameRate: flag == 3
                        )
                        let ghost = monster(item, frames: Self.shakyFrames) == .shakyGhost
                        #expect(measured == ghost,
                                "\(duration) s, \(bytes) B, \(width)x\(height), flag \(flag): measured \(measured), ghost \(ghost)")
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run them and confirm the right ones fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/MonsterClassifierShakeTests test`
Expected: `measuredShakeSummonsAShakyGhost`, `brightnessSwingsAloneAreNotShake`, `shakeOutranksTheBrightnessBasedStillGuess` and `policyAndClassifierAgreeAcrossTheBoundaries` fail; `aSteadyClipIsNotAShakyGhost` and `flickerStillOutranksShake` pass. The brightness test fails because today's luminance rule *does* summon a Shaky Ghost for `[0.3, 0.5, 0.35]`, which is the bug.

- [ ] **Step 3: Use measured shake in the classifier**

In `ios/PurgeQuest/Services/MonsterClassifier.swift`, in `classifyVideo`, replace:

```swift
            if frames.isFlickering {
                return MonsterClassification(
                    monsterType: .flickerWraith, confidence: 0.8,
                    reasons: [.flickeringFrames], estimatedBytes: bytes
                )
            }
            if duration >= staticVideoMinimumDuration && frames.isStatic {
```

with:

```swift
            if frames.isFlickering {
                return MonsterClassification(
                    monsterType: .flickerWraith, confidence: 0.8,
                    reasons: [.flickeringFrames], estimatedBytes: bytes
                )
            }
            // Measured camera motion outranks the brightness-based "static" guess below: a handheld
            // clip of a motionless scene barely changes brightness, yet it is anything but still.
            if frames.isShaky {
                return MonsterClassification(
                    monsterType: .shakyGhost, confidence: 0.75,
                    reasons: [.erraticMotion], estimatedBytes: bytes
                )
            }
            if duration >= staticVideoMinimumDuration && frames.isStatic {
```

remove the old brightness-based branch. Replace:

```swift
            if frames.isErratic {
                return MonsterClassification(
                    monsterType: .shakyGhost, confidence: 0.7,
                    reasons: [.erraticMotion], estimatedBytes: bytes
                )
            }
        }
```

with:

```swift
        }
```

and fix the comment that names the old signal. Replace:

```swift
        // length. The Shaky Ghost is still summoned by erratic sampled frames.
```

with:

```swift
        // length. The Shaky Ghost is summoned by measured camera shake.
```

- [ ] **Step 4: Retire the brightness rule**

In `VideoFrameAnalysisService.swift`, replace:

```swift
    static let flickerSwingThreshold: Double = 0.45
    static let erraticMotionThreshold: Double = 0.14
```

with:

```swift
    static let flickerSwingThreshold: Double = 0.45
```

and replace:

```swift
    /// Unsteady handheld motion.
    var isErratic: Bool { meanMotion >= Self.erraticMotionThreshold }
    /// Unsteady handheld motion, measured from the picture itself rather than from brightness.
```

with:

```swift
    /// Unsteady handheld motion, measured from the picture itself rather than from brightness.
```

Confirm nothing else mentions the removed names: `grep -rn "isErratic\|erraticMotionThreshold" ios` should print nothing.

- [ ] **Step 5: Replace the old test**

In `ios/PurgeQuestTests/BestiaryTests.swift` replace:

```swift
    @Test func erraticMotionUpgradesShakyGhost() {
        var item = makeItem(id: "em", kind: .video, width: 1920, height: 1080, bytes: 5_000_000, duration: 10)
        item.frameSignals = VideoFrameSignals.evaluate(luminances: [0.3, 0.5, 0.35])
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["em"]
        #expect(c?.monsterType == .shakyGhost)
        #expect(c?.reasons.contains(.erraticMotion) == true)
    }
```

with:

```swift
    @Test func measuredShakeSummonsShakyGhost() {
        var item = makeItem(id: "em", kind: .video, width: 1920, height: 1080, bytes: 5_000_000, duration: 10)
        var frames = VideoFrameSignals.evaluate(luminances: [0.5, 0.56, 0.5])
        frames?.shake = ShakeSignals(jitter: 0.02, reversalRatio: 0.6, sampleCount: 15)
        item.frameSignals = frames
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["em"]
        #expect(c?.monsterType == .shakyGhost)
        #expect(c?.reasons.contains(.erraticMotion) == true)
    }
```

If `ios/PurgeQuestTests/ContentReachabilityTests.swift` exists (the content-reachability plan has landed), its Shaky Ghost witness still uses the removed brightness rule. Replace:

```swift
        w.append((.shakyGhost, clip(duration: 10, luminances: [0.3, 0.5, 0.35])))
```

with:

```swift
        var shaky = item("clip", kind: .video, width: 1920, height: 1080, bytes: 20_000_000, duration: 10)
        var shakyFrames = VideoFrameSignals.evaluate(luminances: [0.5, 0.56, 0.5])
        shakyFrames?.shake = ShakeSignals(jitter: 0.02, reversalRatio: 0.6, sampleCount: 15)
        shaky.frameSignals = shakyFrames
        w.append((.shakyGhost, alone(shaky)))
```

- [ ] **Step 6: Run the unit-test target**

Run: `tools/ci/xcode-test.sh`
Expected: PASS, including all six `MonsterClassifierShakeTests` and the rest of `BestiaryTests`. `policyAndClassifierAgreeAcrossTheBoundaries` is the guard that keeps `ShakeAnalysisPolicy` honest: if someone adds a classifier rule that fires earlier, it fails until the policy matches.

- [ ] **Step 7: Commit**

```bash
git add ios/PurgeQuest/Services/MonsterClassifier.swift ios/PurgeQuest/Services/VideoFrameAnalysisService.swift ios/PurgeQuestTests
git commit -m "Summon the Shaky Ghost from measured camera shake, not brightness changes"
```

---

### Task 7: Calibrate on a phone, document, and open the pull request

**Files:**
- Create: `docs/shake-calibration.md`
- Modify: `README.md`

- [ ] **Step 1: Add the calibration guide**

Create `docs/shake-calibration.md`:

```markdown
# Calibrating the Shaky Ghost

`ios/PurgeQuest/Services/CameraMotion.swift` turns a few short runs of decoded frames into three
numbers. The thresholds are starting values chosen from synthetic footage, not from real clips. This
is how to check them against real ones, and what to change if they are wrong.

| Number | Meaning | Starting threshold |
|---|---|---|
| jitter | RMS change in camera velocity from one 0.1 s sample to the next, as a fraction of the picture's long edge | at least 0.010 |
| reversal ratio | share of consecutive moves that flipped direction (a tremor flips, a pan does not) | at least 0.3 |
| sample count | pairs of consecutive moves measured | at least 6 |

A clip is a Shaky Ghost when all three hold (`ShakeSignals.isShaky`).

## Protocol

1. Record about 20 clips of 5 to 15 seconds on the iPhone you target, with the Camera app at its
   default settings. Aim for five of each: **tripod**, **smooth pan**, **standing still, handheld**,
   **walking while filming**.
2. Run a Debug build from Xcode on that iPhone and open the Console. Filter on `category:Shake`.
3. Start a dive that includes the clips. Each measured clip logs one line:
   `shake jitter 0.0123 reversals 0.55 samples 15 shaky true`. A clip that was not measured logs
   nothing (too short or too long, too large, a screen recording, or the dive's time budget ran out).
4. Record one row per clip: what it was, and the three numbers.
5. Read the table:
   - **tripod and smooth pans** must come out *not shaky*. If one is shaky, raise the thresholds.
   - **walking** must come out shaky. If one is not, lower them.
   - **standing still, handheld** is the judgement call. Decide how steady a hand has to be before
     you would call the clip worth reviewing, and put the thresholds between the clips on each side.
6. Edit `ShakeSignals.jitterThreshold` and `reversalThreshold`. Some tests use literal motion sizes
   chosen to sit just either side of the starting thresholds, so moving a threshold can fail them
   for the right reason: `aHandTremorIsShaky` (jitter about 0.014), `footageFromAShakingHandIsShaky`
   (about 0.021), `aMildWobbleBelowTheThresholdIsLeftAlone` (about 0.003) and the fixtures in
   `MonsterClassifierShakeTests` (jitter 0.02 and 0.001). Adjust their numbers to stay on the same
   side of the new threshold, then note the new values and the clips behind them at the bottom of
   this file.

## When the numbers look wrong

- **Every clip reads jitter near 0 with few samples.** The frames are too flat or too dark to match.
  Look for `sampleCount` far below 15 and consider a larger `ShakeSampling.timeBudget`.
- **Tripod clips read as shaky.** Something moves across most of the frame (people, water, foliage)
  and the match locks onto it. That is a limit of global motion estimation; raise `jitterThreshold`.
- **Nothing logs.** Check `ShakeAnalysisPolicy` (clip length, size, resolution, flags) and that the
  dive's `ShakeBudget` was not spent on earlier clips.

## Recorded calibrations

*(none yet)*
```

- [ ] **Step 2: Run the protocol once on a device**

Follow the guide with about 20 clips. Also time a dive that includes many videos, before and after this change, and confirm the extra loading time stays under the 15 s dive budget. If the thresholds need to move, change `ShakeSignals.jitterThreshold` / `reversalThreshold` in `CameraMotion.swift`, then nudge the handful of tests whose literal motion sizes sat just either side of the old values (the calibration guide lists them). Write the new values and the clips behind them under "Recorded calibrations".

- [ ] **Step 3: Update the README**

Replace the Shaky Ghost row:

```markdown
| Screenshot Specter | `PHAsset` screenshot subtype flag | Shaky Ghost | default video fallback |
```

with:

```markdown
| Screenshot Specter | `PHAsset` screenshot subtype flag | Shaky Ghost | measured camera shake (block matching over short frame runs) |
```

and replace the Roadmap bullet:

```markdown
- Real motion/shake analysis (via `AVFoundation` + `Vision` feature points) for the "Shaky Ghost" video classification, which currently is just the default fallback rather than a genuine shake detector — also flagged with a `// TODO` in the same file.
```

with:

```markdown
- Calibrate the Shaky Ghost thresholds on real clips (`docs/shake-calibration.md`).
```

- [ ] **Step 4: Run the checks and open the pull request**

```bash
python3 -I tools/ci/repo_guard.py
SWIFT_BIN=… tools/swift_harness/run.sh --filter CameraMotionTests
git add docs/shake-calibration.md README.md
git commit -m "Document how to calibrate the Shaky Ghost on real clips"
git push -u origin HEAD
```

In the pull request, state plainly which numbers came from a device and which from synthetic footage, and attach the calibration table if you made one.

## Not in this plan

- **Vision's registration requests** (`VNTrackTranslationalImageRegistrationRequest`) could replace the hand-written estimator. They were not used because the estimator's behaviour is fully testable off-device and its failure modes (cuts, flat frames, fast pans) are explicit; the estimator sits behind two pure functions, so a swap would be local.
- **Rotation and zoom.** Block matching measures translation only. Handheld shake is mostly translation at 160 px, but a clip that rotates or zooms will read as motion that matches poorly and be refused rather than mislabelled.
- **Reading the gyroscope.** Photos videos do not carry usable gyro metadata.

## Self-review

- Spec coverage: "actual motion/shake analysis for Shaky Ghost" is met by Tasks 1 to 6; the unverifiable part (thresholds on real footage) has its own task and document.
- Placeholder scan: none; every code step carries its code.
- Type consistency: `GrayFrame`/`MotionEstimate` (Task 1) feed `MotionSample` (Task 2) only through Task 5's glue; `ShakeSignals` (Task 2) is the `VideoFrameSignals.shake` type (Task 5) and the classifier's input (Task 6); `ShakeBudget`/`ShakeAnalysisPolicy` (Task 3) are used by Task 5 and tested against the classifier in Task 6.
- Build stays green between tasks: Task 5 adds `isShaky` and keeps `isErratic`; Task 6 removes it in the same commit that stops the classifier using it.
