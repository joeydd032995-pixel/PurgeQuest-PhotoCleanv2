# Core ML Blur Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a trained on-device Core ML model decide whether a photo is out of focus, keep the Laplacian heuristic as the fallback, and set a measured bar a model must clear before it ships.

**Architecture:** A pure decision function (`BlurDecision`) chooses the model's answer when there is one and the heuristic otherwise. A small service (`BlurModelService`) loads `BlurClassifier` from the app bundle by name at run time, so the app builds and behaves identically with or without the model file. Tooling in `tools/coreml/` builds a labelled training set from the owner's own photos, trains with Create ML, and an opt-in test measures the model against the heuristic on held-out photos; `ModelAcceptance` says whether it may ship.

**Tech Stack:** Swift 5 language mode, Core ML, Vision, Swift Testing; Python 3 with NumPy and Pillow for the dataset tool (development machine only); Create ML (macOS) for training. No new app dependencies.

**Roadmap item:** 3 of 4 ("Upgrade classification with Core ML models (Blur, Video Quality, etc.) while keeping heuristics as fallback"). Independent of the other plans.

## What this plan delivers, and what it does not

**It delivers everything except the trained model file.** A model has to be trained on photos and judged on photos, and there are none in this repository (it holds no user images, and a model trained on synthetic data alone would be a guess). So the plan builds the part that can be built and verified: the runtime, the fallback, the decision logic, the training-set builder, the training script, and a gate. Shipping a model is then a short procedure (Task 5) with a pass/fail answer.

**Until a model passes the gate, nothing changes for players.** With no `BlurClassifier` in the bundle, `BlurModelService` returns nil, `BlurDecision` falls through to the existing Laplacian threshold (9.0, unchanged), and the classifier behaves exactly as today. The one visible improvement that arrives with this plan regardless: a Blur Beast now explains itself as **"Looks out of focus"**. Today its reason is `.lowQuality`, whose text reads "Unusual proportions, likely saved from elsewhere", which is wrong for a blurry photo.

**Video quality is deliberately deferred.** The README lists a `VideoQualityScorer.mlmodel`. No monster is summoned by video quality: a blurry video has no creature, and the Shaky Ghost already covers unsteady footage. A model with no consumer would be dead code. `BlurModelService.blurProbability(for:)` takes any `UIImage`, so scoring a sampled video frame later is one call. The decision to make first is which monster a soft-focus clip should summon, if any; that is a game-design call, not an engineering one.

## What the code actually does today (verified against the tree, not the README)

- No `.mlmodel`, `.mlpackage` or `.mlmodelc` exists in the repository.
- The README says classification sits behind `PhotoClassifier`/`VideoClassifier` protocols in `Services/MediaClassifier.swift`. Neither exists: `MonsterClassifier` is a pure static enum over `MediaItem` and `MediaFingerprint`, and signals are extracted separately (`MLAnalysisService`). This plan adds a seam only where the model needs one (`BlurDecision`), as the project's own Core ML skill advises.
- Blur is `MLAnalysisService.sharpnessVariance(image:)`: Laplacian variance of an 80x80 downsample, compared with `MonsterClassifier.blurSharpness = 9.0` in `classifyPhoto`.

## Verification environment

- **Linux harness:** needs Swift 6.2 or newer (`https://download.swift.org/swift-6.2.1-release/ubuntu2404/swift-6.2.1-RELEASE/swift-6.2.1-RELEASE-ubuntu24.04.tar.gz` for Ubuntu 24.04). Run `SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh --filter BlurModelTests`.
- **Xcode:** `xcodebuild -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug -destination 'platform=iOS Simulator,name=<an iOS 18+ iPhone>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:PurgeQuestTests/<Suite> test`, or `tools/ci/xcode-test.sh`.
- **Python tooling:** `python3 -m pip install numpy pillow pytest`, then `python3 -m pytest tools/coreml -q`.
- **No Mac available:** push and read the "iOS Unit Tests" workflow on the pull request. Do not report an Xcode-only step as passed unless it ran.
- **Verified while writing this plan:** Task 1 was replayed from a clean copy on Swift 6.2.1 in the harness's settings and in the app's settings (Swift 5 mode, default main-actor isolation, approachable concurrency): 16 tests pass in both. The Python tool passes 11 tests here, and its command line was run end to end. The pattern used to hold the non-`Sendable` Vision model in a `nonisolated` static was compiled under the app's settings with a stand-in type. Tasks 2 and 3 edit files that import Photos, UIKit, Core ML and Vision: their edits were applied to the real files (each `old` text matched once), every file was syntax-checked, and `tools/ci/repo_guard.py` (offline, deletion, dependency checks) stays green, but they were **not compiled** against the Apple SDKs. Treat the first Xcode build of Tasks 2 and 3 as the real check. `train_blur_classifier.swift` uses Create ML, which exists only on macOS, and was only syntax-checked; its first run on a Mac either works or fails to compile with an obvious API message.

## Global Constraints

- iOS 18.0+ deployment target; Swift 5 language mode; the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. The pure types are `nonisolated`; the Core ML work runs in `Task.detached`, which the repository already uses (`StoreKitService`).
- **Inference is on the device. Nothing is sent anywhere.** `tools/ci/repo_guard.py` rejects networking APIs in the app; the loader uses `MLModel(contentsOf:)` on a bundled file only. Training data is the owner's own photos on the owner's own Mac.
- No third-party dependencies in the app (`repo_guard.py`). The Python tool's NumPy and Pillow are development-machine tools and are not part of the app.
- The heuristic path must keep working when the model file is absent, fails to load, or returns nothing usable, with a single log line and no thrown error.
- Files listed in `tools/swift_harness/run.sh` must be pure Foundation and must exist.
- New Swift files under `ios/PurgeQuest/` and `ios/PurgeQuestTests/` are picked up automatically. Do not edit `project.pbxproj`.
- Tests use Swift Testing; suites are `@MainActor`, as in `BestiaryTests.swift`.
- Commit messages are plain imperative sentences.

## Decisions this plan makes (change them before executing if you disagree)

1. **Create ML trains the model.** It needs no Python machine-learning stack and produces exactly the contract the app reads. The cost is that training needs a Mac.
2. **Model threshold 0.6, gate: F1 at least 0.05 better than the heuristic, false alarms at most 1 point worse, at least 200 held-out photos.** False alarms are weighted because a wrongly flagged sharp photo is something the player sees and may delete. Edit `ModelAcceptance` if you want a different bar.
3. **The model replaces the heuristic when present.** It is not blended with it. A simple rule is easier to evaluate and to roll back (delete the file).

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `ios/PurgeQuest/Services/BlurDecision.swift` | create | `BlurDecision`, `BlurVerdict`, `BlurSource`, `BlurModelContract` (pure) |
| `ios/PurgeQuest/Services/ModelAcceptance.swift` | create | `BinaryMetrics`, `ModelAcceptance` (pure) |
| `ios/PurgeQuestTests/BlurModelTests.swift` | create | 16 pure tests |
| `tools/swift_harness/run.sh` | modify | Run the above on Linux |
| `ios/PurgeQuest/Models/MonsterClassification.swift` | modify | `ClassificationReason.softFocus` |
| `ios/PurgeQuest/Services/MonsterClassifier.swift` | modify | Use `BlurDecision` |
| `ios/PurgeQuest/Models/MediaItem.swift` | modify | `modelBlurProbability` |
| `ios/PurgeQuestTests/BlurClassificationTests.swift` | create | Classifier behaviour |
| `ios/PurgeQuest/Services/BlurModelService.swift` | create | Load the bundled model; run it off the main actor |
| `ios/PurgeQuest/Services/PhotoLibraryService.swift` | modify | Ask the model for each photo |
| `ios/PurgeQuest/Services/MLAnalysisService.swift` | modify | Replace the stale TODO |
| `ios/PurgeQuestTests/BlurModelServiceTests.swift` | create | Fallback behaviour |
| `ios/PurgeQuestTests/BlurModelEvaluationTests.swift` | create | The opt-in gate |
| `tools/coreml/blur_dataset.py`, `test_blur_dataset.py` | create | Training-set builder and its tests |
| `tools/coreml/train_blur_classifier.swift` | create | Create ML training script |
| `tools/coreml/README.md` | create | The model contract and the procedure |
| `.github/workflows/coreml-tools.yml` | create | Run the Python tests in CI |
| `README.md` | modify | Correct the classification text and the roadmap |

---

### Task 1: The blur decision, the model contract, and the acceptance gate

**Files:**
- Create: `ios/PurgeQuest/Services/BlurDecision.swift`
- Create: `ios/PurgeQuest/Services/ModelAcceptance.swift`
- Create: `ios/PurgeQuestTests/BlurModelTests.swift`
- Modify: `tools/swift_harness/run.sh`

**Interfaces:**
- Produces: `BlurDecision.evaluate(modelBlurProbability: Double?, sharpness: Double?) -> BlurVerdict?`, with `BlurVerdict(isBlurry:source:confidence:)`, `BlurSource` (`.model`, `.heuristic`), and the constants `heuristicSharpnessThreshold` (9.0), `heuristicConfidence` (0.7), `modelBlurThreshold` (0.6); `BlurModelContract.modelName` (`"BlurClassifier"`) and `BlurModelContract.blurProbability(fromLabels:) -> Double?`; `BinaryMetrics` (`record(predictedBlurry:actuallyBlurry:)`, `precision`, `recall`, `f1`, `falsePositiveRate`, `total`); `ModelAcceptance.verdict(model:heuristic:) -> ModelAcceptance.Verdict` (`accepted`, `reasons`).

- [ ] **Step 1: Write the failing tests and register them**

Create `ios/PurgeQuestTests/BlurModelTests.swift`:

```swift
//
//  BlurModelTests.swift
//  PurgeQuestTests
//
//  Pure-Foundation tests for the blur decision, the model contract and the acceptance gate. They
//  also run on the Linux harness (tools/swift_harness/run.sh), so nothing here may touch Core ML,
//  Vision or UIKit.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct BlurModelTests {

    // MARK: - Heuristic fallback

    @Test func theHeuristicAloneCallsLowVarianceBlurry() throws {
        let blurry = try #require(BlurDecision.evaluate(modelBlurProbability: nil, sharpness: 3))
        #expect(blurry.isBlurry)
        #expect(blurry.source == .heuristic)
        #expect(blurry.confidence == BlurDecision.heuristicConfidence)

        let sharp = try #require(BlurDecision.evaluate(modelBlurProbability: nil, sharpness: 60))
        #expect(!sharp.isBlurry)
        #expect(sharp.source == .heuristic)
    }

    @Test func theHeuristicThresholdIsExclusive() throws {
        let edge = BlurDecision.heuristicSharpnessThreshold
        #expect(try #require(BlurDecision.evaluate(modelBlurProbability: nil, sharpness: edge)).isBlurry == false)
        #expect(try #require(BlurDecision.evaluate(modelBlurProbability: nil, sharpness: edge - 0.001)).isBlurry)
    }

    @Test func nothingToGoOnMeansNoVerdict() {
        #expect(BlurDecision.evaluate(modelBlurProbability: nil, sharpness: nil) == nil)
        #expect(BlurDecision.evaluate(modelBlurProbability: nil, sharpness: .nan) == nil)
        #expect(BlurDecision.evaluate(modelBlurProbability: .nan, sharpness: nil) == nil)
    }

    // MARK: - The model, when there is one

    @Test func theModelOutranksTheHeuristicBothWays() throws {
        let modelSaysBlurry = try #require(BlurDecision.evaluate(modelBlurProbability: 0.9, sharpness: 60))
        #expect(modelSaysBlurry.isBlurry)
        #expect(modelSaysBlurry.source == .model)
        #expect(modelSaysBlurry.confidence == 0.9)

        let modelSaysSharp = try #require(BlurDecision.evaluate(modelBlurProbability: 0.1, sharpness: 3))
        #expect(!modelSaysSharp.isBlurry)
        #expect(modelSaysSharp.source == .model)
        #expect(abs(modelSaysSharp.confidence - 0.9) < 1e-12)
    }

    @Test func theModelThresholdIsInclusive() throws {
        let edge = BlurDecision.modelBlurThreshold
        #expect(try #require(BlurDecision.evaluate(modelBlurProbability: edge, sharpness: nil)).isBlurry)
        #expect(try #require(BlurDecision.evaluate(modelBlurProbability: edge - 0.001, sharpness: nil)).isBlurry == false)
    }

    @Test func outOfRangeProbabilitiesAreClamped() throws {
        let high = try #require(BlurDecision.evaluate(modelBlurProbability: 1.7, sharpness: nil))
        #expect(high.isBlurry && high.confidence == 1)
        let low = try #require(BlurDecision.evaluate(modelBlurProbability: -0.4, sharpness: nil))
        #expect(!low.isBlurry && low.confidence == 1)
    }

    @Test func anUnusableModelAnswerFallsBackToTheHeuristic() throws {
        let verdict = try #require(BlurDecision.evaluate(modelBlurProbability: .infinity, sharpness: 3))
        #expect(verdict.source == .heuristic)
        #expect(verdict.isBlurry)
    }

    // MARK: - Reading a classifier's labels

    @Test func theBlurryScoreIsUsedWhenPresent() {
        let labels: [(label: String, score: Double)] = [("sharp", 0.2), ("blurry", 0.8)]
        #expect(BlurModelContract.blurProbability(fromLabels: labels) == 0.8)
    }

    @Test func aLoneSharpScoreIsInverted() throws {
        let probability = try #require(BlurModelContract.blurProbability(fromLabels: [("sharp", 0.9)]))
        #expect(abs(probability - 0.1) < 1e-12)
    }

    @Test func labelsAreMatchedWithoutCaseAndBadScoresAreRefused() {
        #expect(BlurModelContract.blurProbability(fromLabels: [("Blurry", 0.25)]) == 0.25)
        #expect(BlurModelContract.blurProbability(fromLabels: [("blurry", .nan), ("sharp", 0.5)]) == 0.5)
        #expect(BlurModelContract.blurProbability(fromLabels: [("cat", 0.9)]) == nil)
        #expect(BlurModelContract.blurProbability(fromLabels: []) == nil)
        #expect(BlurModelContract.blurProbability(fromLabels: [("blurry", 4)]) == 1)
    }

    // MARK: - Acceptance gate

    private func metrics(tp: Int, fp: Int, tn: Int, fn: Int) -> BinaryMetrics {
        var m = BinaryMetrics()
        for _ in 0..<tp { m.record(predictedBlurry: true, actuallyBlurry: true) }
        for _ in 0..<fp { m.record(predictedBlurry: true, actuallyBlurry: false) }
        for _ in 0..<tn { m.record(predictedBlurry: false, actuallyBlurry: false) }
        for _ in 0..<fn { m.record(predictedBlurry: false, actuallyBlurry: true) }
        return m
    }

    @Test func metricsFollowTheirDefinitions() {
        let m = metrics(tp: 80, fp: 10, tn: 90, fn: 20)
        #expect(m.total == 200)
        #expect(abs(m.precision - 80.0 / 90.0) < 1e-12)
        #expect(abs(m.recall - 0.8) < 1e-12)
        #expect(abs(m.falsePositiveRate - 0.1) < 1e-12)
        let expectedF1 = 2 * m.precision * m.recall / (m.precision + m.recall)
        #expect(abs(m.f1 - expectedF1) < 1e-12)
    }

    @Test func emptyMetricsDoNotDivideByZero() {
        let m = BinaryMetrics()
        #expect(m.precision == 0 && m.recall == 0 && m.f1 == 0 && m.falsePositiveRate == 0)
    }

    @Test func aClearlyBetterModelIsAccepted() {
        let heuristic = metrics(tp: 60, fp: 20, tn: 80, fn: 40)
        let model = metrics(tp: 90, fp: 15, tn: 85, fn: 10)
        let verdict = ModelAcceptance.verdict(model: model, heuristic: heuristic)
        #expect(verdict.accepted, "\(verdict.reasons)")
    }

    @Test func aMarginallyBetterModelIsRefused() {
        let heuristic = metrics(tp: 80, fp: 20, tn: 80, fn: 20)
        let model = metrics(tp: 82, fp: 20, tn: 80, fn: 18)
        let verdict = ModelAcceptance.verdict(model: model, heuristic: heuristic)
        #expect(!verdict.accepted)
        #expect(verdict.reasons.contains { $0.contains("F1") })
    }

    @Test func aModelThatCriesWolfIsRefusedEvenIfItCatchesMoreBlur() {
        let heuristic = metrics(tp: 60, fp: 5, tn: 95, fn: 40)
        let model = metrics(tp: 98, fp: 30, tn: 70, fn: 2)
        let verdict = ModelAcceptance.verdict(model: model, heuristic: heuristic)
        #expect(!verdict.accepted)
        #expect(verdict.reasons.contains { $0.contains("false alarms") })
    }

    @Test func tooFewSamplesOrMismatchedSetsAreRefused() {
        let small = metrics(tp: 40, fp: 5, tn: 45, fn: 10)
        #expect(ModelAcceptance.verdict(model: small, heuristic: small).reasons.contains { $0.contains("at least") })

        let heuristic = metrics(tp: 60, fp: 20, tn: 80, fn: 40)
        let model = metrics(tp: 90, fp: 15, tn: 85, fn: 5)
        #expect(ModelAcceptance.verdict(model: model, heuristic: heuristic).reasons.contains { $0.contains("different sets") })
    }

    // New tests go above this line.
}
```

Create `ios/PurgeQuest/Services/BlurDecision.swift` and `ios/PurgeQuest/Services/ModelAcceptance.swift`, each containing only:

```swift
import Foundation
```

In `tools/swift_harness/run.sh` make three one-token additions. Each `old` text occurs once:

```text
Models/ColorTheme
```

becomes

```text
Models/ColorTheme Services/BlurDecision Services/ModelAcceptance
```

```text
ThemePaletteTests
```

becomes

```text
ThemePaletteTests BlurModelTests
```

and in the header comment

```text
AppearanceMode, ColorTheme
```

becomes

```text
AppearanceMode, ColorTheme, BlurDecision
```

If the duplicate-detection or shake plans have already landed, the same lines also name their files; append yours, the order does not matter.

- [ ] **Step 2: Run them and confirm they fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter BlurModelTests`
Expected: FAIL to compile with `cannot find 'BlurDecision' in scope` and `cannot find type 'BinaryMetrics' in scope`.

- [ ] **Step 3: Write the decision and the contract**

Replace the contents of `ios/PurgeQuest/Services/BlurDecision.swift` with:

```swift
//
//  BlurDecision.swift
//  PurgeQuest
//
//  The "is this photo out of focus?" decision, kept free of Core ML and UIKit so every branch is
//  unit-tested on Linux (tools/swift_harness) as well as in Xcode. BlurModelService produces the
//  optional model probability; MLAnalysisService produces the Laplacian heuristic; this file
//  decides between them: the model when there is one, the heuristic otherwise.
//

import Foundation

nonisolated enum BlurSource: String, Sendable, Equatable {
    case model
    case heuristic
}

nonisolated struct BlurVerdict: Sendable, Equatable {
    let isBlurry: Bool
    let source: BlurSource
    /// 0…1: how sure the verdict is.
    let confidence: Double
}

nonisolated enum BlurDecision {

    /// Laplacian variance (80×80 thumbnail) below which the heuristic calls a photo blurry.
    static let heuristicSharpnessThreshold = 9.0
    /// The heuristic has no notion of degree, so it always reports the same confidence.
    static let heuristicConfidence = 0.7
    /// Model probability at or above which a photo counts as blurry.
    static let modelBlurThreshold = 0.6

    /// Nil when there is nothing to decide on (no model answer and no usable sharpness).
    static func evaluate(modelBlurProbability: Double?, sharpness: Double?) -> BlurVerdict? {
        if let probability = modelBlurProbability, probability.isFinite {
            let clamped = min(1, max(0, probability))
            let blurry = clamped >= modelBlurThreshold
            return BlurVerdict(isBlurry: blurry, source: .model, confidence: blurry ? clamped : 1 - clamped)
        }
        guard let sharpness, sharpness.isFinite else { return nil }
        return BlurVerdict(
            isBlurry: sharpness < heuristicSharpnessThreshold,
            source: .heuristic,
            confidence: heuristicConfidence
        )
    }
}

/// What the app expects of a bundled `BlurClassifier` model, whichever way it was trained: an image
/// classifier whose labels include "blurry" and/or "sharp".
nonisolated enum BlurModelContract {
    static let modelName = "BlurClassifier"
    static let blurryLabel = "blurry"
    static let sharpLabel = "sharp"

    /// Probability that the image is blurry, from the classifier's label scores. Uses the "blurry"
    /// score when present, otherwise one minus the "sharp" score; nil when neither is usable.
    static func blurProbability(fromLabels labels: [(label: String, score: Double)]) -> Double? {
        func score(_ name: String) -> Double? {
            guard let found = labels.first(where: { $0.label.lowercased() == name }),
                  found.score.isFinite else { return nil }
            return min(1, max(0, found.score))
        }
        if let blurry = score(blurryLabel) { return blurry }
        if let sharp = score(sharpLabel) { return 1 - sharp }
        return nil
    }
}
```

- [ ] **Step 4: Write the acceptance gate**

Replace the contents of `ios/PurgeQuest/Services/ModelAcceptance.swift` with:

```swift
//
//  ModelAcceptance.swift
//  PurgeQuest
//
//  The bar a trained model must clear before it is allowed into the app: measured on the same
//  labelled images as the heuristic it would replace. Pure Foundation, unit-tested on Linux.
//

import Foundation

/// Confusion counts for a "blurry?" decision.
nonisolated struct BinaryMetrics: Sendable, Equatable {
    private(set) var truePositives = 0
    private(set) var falsePositives = 0
    private(set) var trueNegatives = 0
    private(set) var falseNegatives = 0

    mutating func record(predictedBlurry: Bool, actuallyBlurry: Bool) {
        switch (predictedBlurry, actuallyBlurry) {
        case (true, true): truePositives += 1
        case (true, false): falsePositives += 1
        case (false, false): trueNegatives += 1
        case (false, true): falseNegatives += 1
        }
    }

    var total: Int { truePositives + falsePositives + trueNegatives + falseNegatives }
    /// Share of "blurry" calls that were right.
    var precision: Double { ratio(truePositives, truePositives + falsePositives) }
    /// Share of truly blurry photos that were caught.
    var recall: Double { ratio(truePositives, truePositives + falseNegatives) }
    var f1: Double {
        let p = precision, r = recall
        return p + r == 0 ? 0 : 2 * p * r / (p + r)
    }
    /// Share of sharp photos wrongly called blurry: what the player experiences as a false alarm.
    var falsePositiveRate: Double { ratio(falsePositives, falsePositives + trueNegatives) }

    private func ratio(_ part: Int, _ whole: Int) -> Double {
        whole == 0 ? 0 : Double(part) / Double(whole)
    }
}

nonisolated enum ModelAcceptance {
    /// Fewest labelled photos the comparison may rest on.
    static let minimumSamples = 200
    /// How much better than the heuristic (F1) the model must be.
    static let minimumF1Gain = 0.05
    /// How many more sharp photos, as a share, the model may wrongly flag than the heuristic does.
    static let maximumExtraFalsePositiveRate = 0.01

    struct Verdict: Equatable, Sendable {
        let accepted: Bool
        /// Why not, in plain words. Empty when accepted.
        let reasons: [String]
    }

    static func verdict(model: BinaryMetrics, heuristic: BinaryMetrics) -> Verdict {
        var reasons: [String] = []
        if model.total < minimumSamples {
            reasons.append("only \(model.total) labelled photos; at least \(minimumSamples) are needed")
        }
        if model.total != heuristic.total {
            reasons.append("the model and the heuristic were scored on different sets (\(model.total) vs \(heuristic.total))")
        }
        let gain = model.f1 - heuristic.f1
        if gain < minimumF1Gain {
            reasons.append(String(format: "F1 improves by %.3f, below the required %.2f", gain, minimumF1Gain))
        }
        let extra = model.falsePositiveRate - heuristic.falsePositiveRate
        if extra > maximumExtraFalsePositiveRate {
            reasons.append(String(format: "false alarms rise by %.3f, above the allowed %.2f", extra, maximumExtraFalsePositiveRate))
        }
        return Verdict(accepted: reasons.isEmpty, reasons: reasons)
    }
}
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter BlurModelTests`
Expected: PASS, 16 tests. Also run `python3 -I tools/ci/repo_guard.py`; it must report no `harness:` problems.

- [ ] **Step 6: Commit**

```bash
git add ios/PurgeQuest/Services/BlurDecision.swift ios/PurgeQuest/Services/ModelAcceptance.swift ios/PurgeQuestTests/BlurModelTests.swift tools/swift_harness/run.sh
git commit -m "Decide blur from a model when there is one and the heuristic otherwise"
```

---

### Task 2: The classifier uses the decision, and a Blur Beast says why

**Files:**
- Modify: `ios/PurgeQuest/Models/MonsterClassification.swift`
- Modify: `ios/PurgeQuest/Models/MediaItem.swift`
- Modify: `ios/PurgeQuest/Services/MonsterClassifier.swift`
- Create: `ios/PurgeQuestTests/BlurClassificationTests.swift`

**Interfaces:**
- Consumes: `BlurDecision` (Task 1).
- Produces: `ClassificationReason.softFocus` ("Looks out of focus"); `MediaItem.modelBlurProbability: Double?`; `MonsterClassifier.blurSharpness` now equals `BlurDecision.heuristicSharpnessThreshold`.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/BlurClassificationTests.swift`:

```swift
//
//  BlurClassificationTests.swift
//  PurgeQuestTests
//
//  How the classifier turns a blur signal into a Blur Beast: the model when one answered, the
//  Laplacian heuristic when none did.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct BlurClassificationTests {

    private func photo(sharpness: Double?, model: Double? = nil) -> MediaItem {
        var item = MediaItem(
            id: "p", kind: .photo, creationDate: Date(), pixelWidth: 4000, pixelHeight: 3000,
            durationSeconds: 0, estimatedBytes: 2_000_000, isFavorite: false, playbackStyle: 1,
            sharpness: sharpness, luminance: 0.5
        )
        item.modelBlurProbability = model
        return item
    }

    @Test func theHeuristicStillSummonsABlurBeastWhenNoModelIsBundled() {
        let c = MonsterClassifier.classifySolo(photo(sharpness: 3))
        #expect(c.monsterType == .blurBeast)
        #expect(c.reasons == [.softFocus])
        #expect(c.confidence == BlurDecision.heuristicConfidence)
    }

    @Test func aSharpPhotoWithNoOtherSignalIsTheRoutineWanderer() {
        let c = MonsterClassifier.classifySolo(photo(sharpness: 60))
        #expect(c.reasons == [.noStrongSignal])
    }

    @Test func aModelThatSaysBlurryWinsOverASharpHeuristic() {
        let c = MonsterClassifier.classifySolo(photo(sharpness: 60, model: 0.92))
        #expect(c.monsterType == .blurBeast)
        #expect(c.reasons == [.softFocus])
        #expect(c.confidence == 0.92)
    }

    @Test func aModelThatSaysSharpWinsOverABlurryHeuristic() {
        let c = MonsterClassifier.classifySolo(photo(sharpness: 3, model: 0.08))
        #expect(c.reasons == [.noStrongSignal])
    }

    @Test func noSignalAtAllIsNotBlur() {
        let c = MonsterClassifier.classifySolo(photo(sharpness: nil, model: nil))
        #expect(c.reasons == [.noStrongSignal])
    }

    @Test func theHeuristicThresholdHasOneSourceOfTruth() {
        #expect(MonsterClassifier.blurSharpness == BlurDecision.heuristicSharpnessThreshold)
    }

    @Test func theBlurBeastExplainsItselfAsOutOfFocus() {
        #expect(ClassificationReason.softFocus.factText == "Looks out of focus")
        #expect(MonsterClassifier.classifySolo(photo(sharpness: 3)).whyText == "Looks out of focus")
    }
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/BlurClassificationTests test`
Expected: FAIL to compile with `value of type 'MediaItem' has no member 'modelBlurProbability'` and `type 'ClassificationReason' has no member 'softFocus'`.

- [ ] **Step 3: Add the reason**

In `ios/PurgeQuest/Models/MonsterClassification.swift` replace:

```swift
    case screenRecording
    case lowQuality
```

with:

```swift
    case screenRecording
    case lowQuality
    case softFocus
```

and replace:

```swift
        case .lowQuality:          return "Unusual proportions, likely saved from elsewhere"
```

with:

```swift
        case .lowQuality:          return "Unusual proportions, likely saved from elsewhere"
        case .softFocus:           return "Looks out of focus"
```

- [ ] **Step 4: Carry the model's answer on the item**

In `ios/PurgeQuest/Models/MediaItem.swift` replace:

```swift
    var luminance: Double? = nil     // Average thumbnail luminance
```

with:

```swift
    var luminance: Double? = nil     // Average thumbnail luminance
    var modelBlurProbability: Double? = nil  // Core ML blur model's answer; nil without a bundled model
```

- [ ] **Step 5: Use the decision in the classifier**

In `ios/PurgeQuest/Services/MonsterClassifier.swift` replace:

```swift
    static let blurSharpness: Double = 9.0
```

with:

```swift
    static let blurSharpness: Double = BlurDecision.heuristicSharpnessThreshold
```

and in `classifyPhoto` replace:

```swift
        // Cheap thumbnail heuristics.
        if let sharpness = item.sharpness, sharpness < blurSharpness {
            return MonsterClassification(
                monsterType: .blurBeast, confidence: 0.7,
                reasons: [.lowQuality], estimatedBytes: bytes
            )
        }
```

with:

```swift
        // Out of focus: the on-device model when one is bundled, the Laplacian heuristic otherwise.
        if let blur = BlurDecision.evaluate(modelBlurProbability: item.modelBlurProbability, sharpness: item.sharpness),
           blur.isBlurry {
            return MonsterClassification(
                monsterType: .blurBeast, confidence: blur.confidence,
                reasons: [.softFocus], estimatedBytes: bytes
            )
        }
        // Cheap thumbnail heuristics.
```

The threshold is the same 9.0, so nothing changes for a library with no model; the only difference is the reason text and that `confidence` now comes from the verdict (still 0.7 for the heuristic).

- [ ] **Step 6: Run the tests, then the whole target**

Run: `xcodebuild … -only-testing:PurgeQuestTests/BlurClassificationTests test`, then `tools/ci/xcode-test.sh`.
Expected: PASS, seven tests; the existing `blurryImageSummonsBlurBeast` in `BestiaryTests` still passes. (Searched while writing this plan: no existing test asserts the old `.lowQuality` reason on a Blur Beast.)

- [ ] **Step 7: Commit**

```bash
git add ios/PurgeQuest/Models/MonsterClassification.swift ios/PurgeQuest/Models/MediaItem.swift ios/PurgeQuest/Services/MonsterClassifier.swift ios/PurgeQuestTests/BlurClassificationTests.swift
git commit -m "Let a blur model outrank the heuristic and explain a Blur Beast as out of focus"
```

---

### Task 3: Load the bundled model, run it, and fall back safely

**Files:**
- Create: `ios/PurgeQuest/Services/BlurModelService.swift`
- Modify: `ios/PurgeQuest/Services/PhotoLibraryService.swift`
- Modify: `ios/PurgeQuest/Services/MLAnalysisService.swift`
- Create: `ios/PurgeQuestTests/BlurModelServiceTests.swift`

**Interfaces:**
- Consumes: `BlurModelContract` (Task 1), `MediaItem.modelBlurProbability` (Task 2).
- Produces: `BlurModelService.modelName`, `.bundled: BlurModelHandle?`, `.load(named:in:) -> BlurModelHandle?`, `.blurProbability(for: UIImage) async -> Double?`.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/BlurModelServiceTests.swift`:

```swift
//
//  BlurModelServiceTests.swift
//  PurgeQuestTests
//
//  The model is optional: these tests hold whether or not a BlurClassifier is bundled.
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct BlurModelServiceTests {

    private func sampleImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.white.setFill()
            context.fill(CGRect(x: 16, y: 16, width: 32, height: 32))
        }
    }

    @Test func aMissingModelLoadsAsNilNotAnError() {
        #expect(BlurModelService.load(named: "NoSuchModel", in: .main) == nil)
    }

    @Test func theAppAndTheDocsAgreeOnTheModelName() {
        #expect(BlurModelService.modelName == "BlurClassifier")
        #expect(BlurModelService.modelName == BlurModelContract.modelName)
    }

    @Test func anAnswerExistsExactlyWhenAModelIsBundled() async {
        let answer = await BlurModelService.blurProbability(for: sampleImage())
        if BlurModelService.bundled == nil {
            #expect(answer == nil)
        } else {
            #expect(answer != nil)
            #expect((0...1).contains(answer ?? -1))
        }
    }

    @Test func anImageWithoutPixelsGetsNoAnswer() async {
        #expect(await BlurModelService.blurProbability(for: UIImage()) == nil)
    }
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/BlurModelServiceTests test`
Expected: FAIL to compile with `cannot find 'BlurModelService' in scope`.

- [ ] **Step 3: Write the service**

Create `ios/PurgeQuest/Services/BlurModelService.swift`:

```swift
//
//  BlurModelService.swift
//  PurgeQuest
//
//  Runs the optional on-device blur classifier. The model is looked up by name in the app bundle
//  and loaded at run time, so the app builds and behaves identically with or without it: no model
//  file means no answer, and the Laplacian heuristic in MLAnalysisService decides alone
//  (see BlurDecision). Everything runs on the device. tools/coreml/README.md explains how a model
//  is trained and when it may ship.
//

import Foundation
import CoreML
import Vision
import UIKit
import os

/// Lets the loaded Vision model live in a static and cross into a background task. The model is
/// only ever read once it is loaded.
nonisolated final class BlurModelHandle: @unchecked Sendable {
    let model: VNCoreMLModel
    init(model: VNCoreMLModel) { self.model = model }
}

enum BlurModelService {

    nonisolated static let modelName = BlurModelContract.modelName
    nonisolated private static let log = Logger(subsystem: "PurgeQuest", category: "BlurModel")

    /// The bundled model, loaded once on first use; nil when the app ships without one.
    nonisolated static let bundled: BlurModelHandle? = load(named: modelName, in: .main)

    /// Loads `<name>.mlmodelc` (Xcode compiles a bundled .mlmodel or .mlpackage into that). Nil,
    /// with one log line, when the model is absent or unusable: never an error for the caller.
    nonisolated static func load(named name: String, in bundle: Bundle) -> BlurModelHandle? {
        guard let url = bundle.url(forResource: name, withExtension: "mlmodelc") else {
            log.info("\(name, privacy: .public) is not bundled: blur falls back to the Laplacian heuristic")
            return nil
        }
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let model = try MLModel(contentsOf: url, configuration: configuration)
            return BlurModelHandle(model: try VNCoreMLModel(for: model))
        } catch {
            log.error("\(name, privacy: .public) failed to load: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Probability (0…1) that the image is blurry, or nil when there is no usable model answer.
    /// Inference runs off the main actor.
    nonisolated static func blurProbability(for image: UIImage) async -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> Double? in
            guard let handle = bundled else { return nil }
            return infer(cgImage, with: handle)
        }.value
    }

    nonisolated private static func infer(_ cgImage: CGImage, with handle: BlurModelHandle) -> Double? {
        let request = VNCoreMLRequest(model: handle.model)
        // Blur is a property of the whole frame: show the model all of it, not a centre crop.
        request.imageCropAndScaleOption = .scaleFill
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            log.error("blur inference failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        guard let observations = request.results as? [VNClassificationObservation] else {
            log.error("\(modelName, privacy: .public) is not an image classifier: no label scores in its output")
            return nil
        }
        return BlurModelContract.blurProbability(
            fromLabels: observations.map { (label: $0.identifier, score: Double($0.confidence)) }
        )
    }
}
```

Three details matter. `BlurModelHandle` wraps the Vision model because `VNCoreMLModel` is not `Sendable` and has to live in a `nonisolated` static and cross into a detached task. Inference runs in `Task.detached` so Core ML never blocks the main actor. And `imageCropAndScaleOption = .scaleFill` shows the model the whole frame: blur is global, and a centre crop would judge only the middle of the picture.

- [ ] **Step 4: Ask the model for each photo**

In `ios/PurgeQuest/Services/PhotoLibraryService.swift`, in `buildMediaItems`, replace:

```swift
            if withThumbnails, let thumb {
                vision = await VisionAnalysisService.analyze(image: thumb)
            }
```

with:

```swift
            if withThumbnails, let thumb {
                vision = await VisionAnalysisService.analyze(image: thumb)
            }
            // Optional Core ML blur model: nil (and free) when the app ships without one.
            var blurProbability: Double? = nil
            if withThumbnails, asset.mediaType == .image, let thumb {
                blurProbability = await BlurModelService.blurProbability(for: thumb)
            }
```

and replace:

```swift
            item.frameSignals = frames
            item.visionSignals = vision
```

with:

```swift
            item.frameSignals = frames
            item.visionSignals = vision
            item.modelBlurProbability = blurProbability
```

If the shake plan has already landed, `buildMediaItems` also declares `motionBudget` and builds `frames`; leave those alone, these edits touch different lines.

- [ ] **Step 5: Replace the stale TODO**

In `ios/PurgeQuest/Services/MLAnalysisService.swift` replace:

```swift
//  TODO: Replace the blur/luminance heuristics with CoreML
//  BlurClassifier.mlmodel + VideoQualityScorer.mlmodel when available.
```

with:

```swift
//  The optional Core ML blur model lives in BlurModelService; BlurDecision chooses between its
//  answer and the Laplacian heuristic measured here.
```

- [ ] **Step 6: Run the tests, then the whole target and the guard**

Run: `xcodebuild … -only-testing:PurgeQuestTests/BlurModelServiceTests test`, then `tools/ci/xcode-test.sh`, then `python3 -I tools/ci/repo_guard.py`.
Expected: PASS everywhere. With no model in the bundle `blurProbability(for:)` returns nil and `anAnswerExistsExactlyWhenAModelIsBundled` takes its nil branch; the same test takes the other branch once a model is added, so it stays correct either way.

- [ ] **Step 7: Commit**

```bash
git add ios/PurgeQuest/Services/BlurModelService.swift ios/PurgeQuest/Services/PhotoLibraryService.swift ios/PurgeQuest/Services/MLAnalysisService.swift ios/PurgeQuestTests/BlurModelServiceTests.swift
git commit -m "Load an optional bundled blur model and fall back to the heuristic without it"
```

---

### Task 4: Tooling to build a training set, train, and judge

**Files:**
- Create: `tools/coreml/test_blur_dataset.py`, `tools/coreml/blur_dataset.py`
- Create: `tools/coreml/train_blur_classifier.swift`
- Create: `tools/coreml/README.md`
- Create: `.github/workflows/coreml-tools.yml`
- Create: `ios/PurgeQuestTests/BlurModelEvaluationTests.swift`

- [ ] **Step 1: Write the failing Python tests**

Create `tools/coreml/test_blur_dataset.py`:

```python
"""Tests for blur_dataset.py. Run: python3 -m pytest tools/coreml -q"""
import random
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blur_dataset as bd  # noqa: E402


def textured(size=96, seed=3) -> Image.Image:
    """A detailed picture: smoothed noise at two scales, so blurring has something to remove."""
    rng = np.random.default_rng(seed)
    coarse = np.kron(rng.random((8, 8)), np.ones((size // 8, size // 8)))
    fine = rng.random((size, size))
    pixels = np.clip(40 + 120 * coarse + 90 * fine, 0, 255).astype(np.uint8)
    return Image.fromarray(np.stack([pixels, pixels[::-1], pixels.T], axis=-1))


def test_kernels_are_normalised():
    assert bd.line_kernel(15, 30).sum() == pytest.approx(1.0)
    assert bd.disk_kernel(4.0).sum() == pytest.approx(1.0)
    assert bd.line_kernel(10, 0).shape[0] % 2 == 1


def test_fft_convolution_matches_direct_computation():
    image = textured(24, seed=5)
    kernel = bd.disk_kernel(2.0)
    fast = np.asarray(bd.convolve(image, kernel), dtype=np.float64)
    pixels = np.asarray(image, dtype=np.float64)
    pad_y, pad_x = kernel.shape[0] // 2, kernel.shape[1] // 2
    padded = np.pad(pixels, ((pad_y, pad_y), (pad_x, pad_x), (0, 0)), mode="reflect")
    slow = np.zeros_like(pixels)
    for y in range(pixels.shape[0]):
        for x in range(pixels.shape[1]):
            window = padded[y:y + kernel.shape[0], x:x + kernel.shape[1], :]
            slow[y, x] = (window * kernel[:, :, None]).sum(axis=(0, 1))
    assert np.abs(fast - np.clip(np.rint(slow), 0, 255)).max() <= 1


@pytest.mark.parametrize("blur", [
    lambda im: bd.gaussian_blur(im, 3.0),
    lambda im: bd.motion_blur(im, 15, 20),
    lambda im: bd.defocus_blur(im, 4.0),
])
def test_every_blur_lowers_the_apps_sharpness_measure(blur):
    image = textured()
    assert bd.laplacian_variance(blur(image)) < bd.laplacian_variance(image) * 0.7


def test_motion_blur_smears_along_its_angle_only():
    rng = np.random.default_rng(2)
    rows = np.repeat(rng.integers(30, 220, (64, 1)), 64, axis=1).astype(np.uint8)  # varies only down the picture
    columns = rows.T.copy()                                                         # varies only across it

    def as_image(grey):
        return Image.fromarray(np.stack([grey, grey, grey], axis=-1))

    # Smearing left-right cannot change a picture that only varies top-to-bottom ...
    unchanged = bd.motion_blur(as_image(rows), 21, 0)
    assert np.abs(np.asarray(unchanged, dtype=float) - np.asarray(as_image(rows), dtype=float)).mean() < 1.0
    # ... but it flattens one that only varies left-to-right.
    flattened = bd.motion_blur(as_image(columns), 21, 0)
    assert bd.laplacian_variance(flattened) < 0.3 * bd.laplacian_variance(as_image(columns))


def make_source(folder: Path, count=3):
    folder.mkdir()
    for i in range(count):
        textured(160, seed=10 + i).save(folder / f"photo{i}.jpg", quality=95)
    (folder / "notes.txt").write_text("not an image")


def test_build_writes_matching_classes_deterministically(tmp_path):
    make_source(tmp_path / "src")
    first = bd.build(tmp_path / "src", tmp_path / "a", per_image=2, seed=7)
    second = bd.build(tmp_path / "src", tmp_path / "b", per_image=2, seed=7)
    assert first == second == {"sharp": 6, "blurry": 6}
    names = sorted(p.name for p in (tmp_path / "a" / "sharp").iterdir())
    assert names == sorted(p.name for p in (tmp_path / "a" / "blurry").iterdir())
    for cls in ("sharp", "blurry"):
        for name in names:
            assert (tmp_path / "a" / cls / name).read_bytes() == (tmp_path / "b" / cls / name).read_bytes()


def test_each_blurry_example_is_blurrier_than_its_sharp_twin(tmp_path):
    make_source(tmp_path / "src")
    bd.build(tmp_path / "src", tmp_path / "out", per_image=2, seed=3)
    for path in (tmp_path / "out" / "sharp").iterdir():
        sharp = bd.laplacian_variance(Image.open(path))
        blurry = bd.laplacian_variance(Image.open(tmp_path / "out" / "blurry" / path.name))
        assert blurry < sharp


def test_examples_are_square_and_the_requested_size(tmp_path):
    make_source(tmp_path / "src", count=1)
    bd.build(tmp_path / "src", tmp_path / "out", per_image=1, seed=1)
    for path in (tmp_path / "out").rglob("*.jpg"):
        assert Image.open(path).size == (bd.SIZE, bd.SIZE)


def test_command_line_reports_problems(tmp_path, capsys):
    assert bd.main(["--source", str(tmp_path / "missing"), "--out", str(tmp_path / "o")]) == 2
    (tmp_path / "empty").mkdir()
    assert bd.main(["--source", str(tmp_path / "empty"), "--out", str(tmp_path / "o")]) == 1
    make_source(tmp_path / "src", count=1)
    assert bd.main(["--source", str(tmp_path / "src"), "--out", str(tmp_path / "o2"), "--per-image", "1"]) == 0
    assert "wrote 1 sharp and 1 blurry" in capsys.readouterr().out


def test_random_crop_is_reproducible():
    image = textured(120)
    a = bd.random_square_crop(image, 64, random.Random(5))
    b = bd.random_square_crop(image, 64, random.Random(5))
    assert np.array_equal(np.asarray(a), np.asarray(b))
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `python3 -m pip install numpy pillow pytest && python3 -m pytest tools/coreml -q`
Expected: FAIL at collection with `ModuleNotFoundError: No module named 'blur_dataset'`.

- [ ] **Step 3: Write the dataset builder**

Create `tools/coreml/blur_dataset.py`:

```python
#!/usr/bin/env python3
"""Builds a labelled sharp/blurry image set from your own photos, entirely offline.

    python3 tools/coreml/blur_dataset.py --source ~/Pictures/Training --out ~/BlurSet --per-image 2

Each source photo yields `--per-image` random square crops. Every crop is saved once as a sharp
example and once more, blurred by a random kind and amount, as a blurry example, so the two classes
are the same pictures and differ only in focus. The output has the layout Create ML reads:

    OUT/sharp/00000_0.jpg ...
    OUT/blurry/00000_0.jpg ...

Nothing is uploaded or downloaded: the script reads local files and writes local files.
Only JPEG and PNG sources are read; export HEIC photos as JPEG first.
"""
import argparse
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SUFFIXES = {".jpg", ".jpeg", ".png"}
SIZE = 224                      # pixels on a side; blur strengths below are in these pixels
GAUSSIAN_SIGMA = (1.6, 5.0)
MOTION_LENGTH = (9, 25)
DEFOCUS_RADIUS = (2.5, 6.0)


def laplacian_variance(image: Image.Image, size: int = 80) -> float:
    """Sharpness the way the app measures it: Laplacian variance of an 80x80 grayscale thumbnail."""
    gray = np.asarray(image.convert("L").resize((size, size), Image.BILINEAR), dtype=np.float64)
    laplacian = (gray[:-2, 1:-1] + gray[2:, 1:-1] + gray[1:-1, :-2] + gray[1:-1, 2:]
                 - 4 * gray[1:-1, 1:-1])
    return float(laplacian.var())


def line_kernel(length: int, angle_degrees: float) -> np.ndarray:
    """Normalised straight-line kernel: what a camera sweeping sideways smears a point into."""
    size = length if length % 2 else length + 1
    centre = size // 2
    kernel = np.zeros((size, size))
    dx, dy = np.cos(np.radians(angle_degrees)), np.sin(np.radians(angle_degrees))
    for t in np.linspace(-centre, centre, size * 4):
        kernel[int(round(centre + t * dy)), int(round(centre + t * dx))] = 1.0
    return kernel / kernel.sum()


def disk_kernel(radius: float) -> np.ndarray:
    """Normalised disc kernel: what a lens that missed focus smears a point into."""
    centre = int(np.ceil(radius))
    y, x = np.ogrid[-centre:centre + 1, -centre:centre + 1]
    kernel = (x * x + y * y <= radius * radius).astype(np.float64)
    return kernel / kernel.sum()


def convolve(image: Image.Image, kernel: np.ndarray) -> Image.Image:
    """Convolve every channel with a centred kernel (edges reflected), using FFTs."""
    pixels = np.asarray(image.convert("RGB"), dtype=np.float64)
    pad_y, pad_x = kernel.shape[0] // 2, kernel.shape[1] // 2
    padded = np.pad(pixels, ((pad_y, pad_y), (pad_x, pad_x), (0, 0)), mode="reflect")
    height, width = padded.shape[:2]
    kernel_spectrum = np.fft.rfft2(kernel, s=(height, width))
    result = np.empty_like(pixels)
    for channel in range(3):
        full = np.fft.irfft2(np.fft.rfft2(padded[:, :, channel]) * kernel_spectrum, s=(height, width))
        result[:, :, channel] = full[2 * pad_y:2 * pad_y + pixels.shape[0],
                                     2 * pad_x:2 * pad_x + pixels.shape[1]]
    return Image.fromarray(np.clip(np.rint(result), 0, 255).astype(np.uint8))


def gaussian_blur(image: Image.Image, sigma: float) -> Image.Image:
    return image.filter(ImageFilter.GaussianBlur(radius=sigma))


def motion_blur(image: Image.Image, length: int, angle_degrees: float) -> Image.Image:
    return convolve(image, line_kernel(length, angle_degrees))


def defocus_blur(image: Image.Image, radius: float) -> Image.Image:
    return convolve(image, disk_kernel(radius))


def random_blur(image: Image.Image, rng: random.Random) -> Image.Image:
    kind = rng.choice(["gaussian", "motion", "defocus"])
    if kind == "gaussian":
        return gaussian_blur(image, rng.uniform(*GAUSSIAN_SIGMA))
    if kind == "motion":
        return motion_blur(image, rng.randint(*MOTION_LENGTH), rng.uniform(0, 180))
    return defocus_blur(image, rng.uniform(*DEFOCUS_RADIUS))


def random_square_crop(image: Image.Image, size: int, rng: random.Random) -> Image.Image:
    shortest = min(image.size)
    side = max(2, int(shortest * rng.uniform(0.4, 1.0)))
    left = rng.randint(0, image.width - side)
    top = rng.randint(0, image.height - side)
    return image.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)


def build(source: Path, out: Path, per_image: int = 2, seed: int = 1, size: int = SIZE) -> dict:
    """Writes OUT/sharp and OUT/blurry; returns how many examples each class received."""
    rng = random.Random(seed)
    sharp_dir, blurry_dir = out / "sharp", out / "blurry"
    sharp_dir.mkdir(parents=True, exist_ok=True)
    blurry_dir.mkdir(parents=True, exist_ok=True)
    counts = {"sharp": 0, "blurry": 0}
    for index, path in enumerate(sorted(p for p in source.rglob("*") if p.suffix.lower() in SUFFIXES)):
        with Image.open(path) as opened:
            image = opened.convert("RGB")
        for k in range(per_image):
            crop = random_square_crop(image, size, rng)
            crop.save(sharp_dir / f"{index:05d}_{k}.jpg", quality=90)
            random_blur(crop, rng).save(blurry_dir / f"{index:05d}_{k}.jpg", quality=90)
            counts["sharp"] += 1
            counts["blurry"] += 1
    return counts


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Build a sharp/blurry training set from local photos.")
    parser.add_argument("--source", type=Path, required=True, help="folder of JPEG/PNG photos (searched recursively)")
    parser.add_argument("--out", type=Path, required=True, help="folder to create sharp/ and blurry/ in")
    parser.add_argument("--per-image", type=int, default=2, help="crops taken from each photo (default 2)")
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args(argv)
    if not args.source.is_dir():
        print(f"not a folder: {args.source}", file=sys.stderr)
        return 2
    counts = build(args.source, args.out, args.per_image, args.seed)
    if counts["sharp"] == 0:
        print("no JPEG or PNG photos found in the source folder", file=sys.stderr)
        return 1
    print(f"wrote {counts['sharp']} sharp and {counts['blurry']} blurry examples to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `python3 -m pytest tools/coreml -q`
Expected: `11 passed`. They check that the FFT convolution matches a direct computation, that every blur kind lowers the app's own sharpness measure, that motion blur smears only along its angle, that the output is deterministic for a seed, and that each blurry example is blurrier than its sharp twin.

Then run the command line once on a handful of your own photos to see it work:

```bash
python3 tools/coreml/blur_dataset.py --source ~/Pictures/Training --out /tmp/BlurSet --per-image 2
```

Expected: `wrote N sharp and N blurry examples to /tmp/BlurSet`.

- [ ] **Step 5: Add the training script**

Create `tools/coreml/train_blur_classifier.swift`:

```swift
#!/usr/bin/env swift
// Trains the BlurClassifier with Create ML (macOS only; Create ML does not exist on Linux or iOS).
//
//   swift tools/coreml/train_blur_classifier.swift DATASET OUTPUT
//
// DATASET holds two folders, `sharp` and `blurry` (tools/coreml/blur_dataset.py builds them).
// OUTPUT receives BlurClassifier.mlmodel, labelled "sharp" and "blurry" as the app expects.
// Nothing is sent anywhere: training happens on this Mac.

import CreateML
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: train_blur_classifier.swift DATASET OUTPUT\n".utf8))
    exit(2)
}
let dataset = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

let classifier = try MLImageClassifier(trainingData: .labeledDirectories(at: dataset))
print("training accuracy:   \(100 * (1 - classifier.trainingMetrics.classificationError))%")
print("validation accuracy: \(100 * (1 - classifier.validationMetrics.classificationError))%")

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let destination = output.appendingPathComponent("BlurClassifier.mlmodel")
try classifier.write(
    to: destination,
    metadata: MLModelMetadata(
        author: "PurgeQuest",
        shortDescription: "Sharp or blurry? Labels: sharp, blurry.",
        version: "1.0"
    )
)
print("wrote \(destination.path)")
```

- [ ] **Step 6: Add the opt-in evaluation test**

Create `ios/PurgeQuestTests/BlurModelEvaluationTests.swift`:

```swift
//
//  BlurModelEvaluationTests.swift
//  PurgeQuestTests
//
//  The gate a trained BlurClassifier must pass before it ships. Skipped unless
//  PQ_BLUR_EVAL_DIR points at a folder with `sharp/` and `blurry/` subfolders of held-out photos
//  (tools/coreml/README.md). On the command line: TEST_RUNNER_PQ_BLUR_EVAL_DIR=/path xcodebuild test ...
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct BlurModelEvaluationTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PQ_BLUR_EVAL_DIR"] != nil))
    func theBundledModelBeatsTheHeuristicOnHeldOutPhotos() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["PQ_BLUR_EVAL_DIR"])
        _ = try #require(BlurModelService.bundled, "no BlurClassifier model is bundled in the app")

        var model = BinaryMetrics()
        var heuristic = BinaryMetrics()
        for (label, isBlurry) in [("sharp", false), ("blurry", true)] {
            let folder = URL(fileURLWithPath: path).appendingPathComponent(label)
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.path < $1.path }
            for file in files {
                guard let image = UIImage(contentsOfFile: file.path) else { continue }
                let byHeuristic = BlurDecision.evaluate(
                    modelBlurProbability: nil, sharpness: MLAnalysisService.sharpnessVariance(image: image)
                )
                heuristic.record(predictedBlurry: byHeuristic?.isBlurry ?? false, actuallyBlurry: isBlurry)
                let byModel = BlurDecision.evaluate(
                    modelBlurProbability: await BlurModelService.blurProbability(for: image), sharpness: nil
                )
                model.record(predictedBlurry: byModel?.isBlurry ?? false, actuallyBlurry: isBlurry)
            }
        }

        let verdict = ModelAcceptance.verdict(model: model, heuristic: heuristic)
        print("""
        blur evaluation on \(model.total) photos
          heuristic: precision \(heuristic.precision), recall \(heuristic.recall), F1 \(heuristic.f1), false alarms \(heuristic.falsePositiveRate)
          model:     precision \(model.precision), recall \(model.recall), F1 \(model.f1), false alarms \(model.falsePositiveRate)
          verdict:   \(verdict.accepted ? "ACCEPTED" : "REFUSED: " + verdict.reasons.joined(separator: "; "))
        """)
        #expect(verdict.accepted, "\(verdict.reasons)")
    }
}
```

It is skipped in normal runs (`.enabled(if:)` on the environment variable), so it never blocks CI. Run `tools/ci/xcode-test.sh` and confirm the target still builds and passes with the test skipped.

- [ ] **Step 7: Write the procedure and the CI job**

Create `tools/coreml/README.md`:

````markdown
# Blur model tooling

The app can use an on-device Core ML classifier to decide whether a photo is out of focus. It works
without one: when `BlurClassifier` is not in the app, the Laplacian-variance heuristic decides alone
(`BlurDecision`, `MLAnalysisService`). This folder holds what is needed to make a model and to decide
whether it may ship. Everything runs on your own machine, on your own photos. Nothing is uploaded.

## The contract

| | |
|---|---|
| File | `BlurClassifier.mlmodel` or `.mlpackage`, added to the app target. Xcode compiles it to `BlurClassifier.mlmodelc`. |
| Type | Image classifier |
| Labels | `sharp` and/or `blurry`, in any letter case |
| Input | Any image. Vision scales the whole frame to the model's input size. |
| Output | Label scores. The app reads `blurry`, or `1 - sharp` when only `sharp` is present. |
| Threshold | `BlurDecision.modelBlurThreshold` (0.6): at or above is blurry. |

The app loads the model by name at run time (`BlurModelService`). No code refers to a generated
class, so adding or removing the file needs no code change, and the app builds and runs the same
either way.

## 1. Build a training set

```bash
python3 -m pip install numpy pillow
python3 tools/coreml/blur_dataset.py --source ~/Pictures/Training --out ~/BlurSet --per-image 2
```

Every source photo yields random square crops. Each crop is saved sharp and again blurred (Gaussian,
motion or defocus, random strength), so the two classes are the same pictures and differ only in
focus. Use JPEG or PNG; export HEIC photos as JPEG first. A few hundred photos is a sensible start.

Make a second set from **different** photos for the final check, and never train on it:

```bash
python3 tools/coreml/blur_dataset.py --source ~/Pictures/Heldout --out ~/BlurHeldout --per-image 2 --seed 2
```

## 2. Train (macOS only)

```bash
swift tools/coreml/train_blur_classifier.swift ~/BlurSet ~/BlurModel
```

This uses Create ML's image classifier and writes `~/BlurModel/BlurClassifier.mlmodel`. Add that file
to the PurgeQuest target in Xcode.

## 3. Judge it against the heuristic

```bash
TEST_RUNNER_PQ_BLUR_EVAL_DIR="$HOME/BlurHeldout" xcodebuild test \
  -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:PurgeQuestTests/BlurModelEvaluationTests
```

The test runs the Laplacian heuristic and the model over the same held-out photos and prints
precision, recall, F1 and the false-alarm rate for each. `ModelAcceptance` decides:

- at least 200 labelled photos;
- the model's F1 is at least 0.05 higher than the heuristic's;
- the model flags no more than 1 point more sharp photos as blurry (false alarms are what players notice).

A model that fails is not shipped. Remove it from the target; the app falls back to the heuristic.

Synthetic blur is not the same as the blur in real photos. Before shipping, also open the app on a
device with a library that has real soft shots and confirm the Blur Beasts it summons look blurry.

## 4. Shipping, rolling back, retraining

- **Ship:** commit the `.mlmodel`, record the held-out numbers in the pull request, and note the
  version in the model's metadata.
- **Roll back:** delete the file from the target. Nothing else changes.
- **Retrain:** repeat steps 1 to 3 with more or different photos. Keep the held-out set fixed so
  the numbers stay comparable between versions.
````

Create `.github/workflows/coreml-tools.yml`:

```yaml
name: Core ML tools

on:
  push:
    branches: [main]
    paths:
      - 'tools/coreml/**'
      - '.github/workflows/coreml-tools.yml'
  pull_request:
    branches: [main]
    paths:
      - 'tools/coreml/**'
      - '.github/workflows/coreml-tools.yml'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  tests:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install test dependencies
        run: python -m pip install numpy pillow pytest
      - name: Blur dataset builder tests
        run: python -m pytest tools/coreml -q
```

- [ ] **Step 8: Commit**

```bash
git add tools/coreml .github/workflows/coreml-tools.yml ios/PurgeQuestTests/BlurModelEvaluationTests.swift
git commit -m "Add the tooling to train a blur model and judge it against the heuristic"
```

---

### Task 5: Train, judge, and either ship or stop

This task needs a Mac, some of your photos, and a decision. It produces a yes or a no, and both are fine outcomes.

- [ ] **Step 1: Build the two sets and train**

Follow `tools/coreml/README.md` steps 1 and 2: a training set from one folder of photos, a held-out set from a different folder, then `swift tools/coreml/train_blur_classifier.swift ~/BlurSet ~/BlurModel`.

- [ ] **Step 2: Add the model and run the gate**

Drag `~/BlurModel/BlurClassifier.mlmodel` into `ios/PurgeQuest/` in Xcode with the PurgeQuest target ticked, then run:

```bash
TEST_RUNNER_PQ_BLUR_EVAL_DIR="$HOME/BlurHeldout" xcodebuild test \
  -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug \
  -destination 'platform=iOS Simulator,name=<an iOS 18+ iPhone>' CODE_SIGNING_ALLOWED=NO \
  -only-testing:PurgeQuestTests/BlurModelEvaluationTests
```

Expected: a printed comparison and either `ACCEPTED` or `REFUSED: …` with reasons.

- [ ] **Step 3: Decide**

- **ACCEPTED:** also open the app on a device with real soft shots in the library and check that the Blur Beasts look blurry (the training blur is synthetic). Commit the model, put the held-out numbers in the pull request, and run `tools/ci/xcode-test.sh`.
- **REFUSED:** remove the model from the target and do not commit it. The app keeps using the heuristic. Read the reasons: too few photos, or a model no better than the heuristic, usually means more or more varied training photos; false alarms usually mean the training blur was stronger than real softness (lower `GAUSSIAN_SIGMA`, `MOTION_LENGTH` and `DEFOCUS_RADIUS` in `blur_dataset.py`).

- [ ] **Step 4: Update the README and open the pull request**

In `README.md` replace each of these (the first three describe classification text this plan made stale):

```markdown
`Services/MLAnalysisService.swift` classifies each photo/video using cheap on-device heuristics — no bundled ML model yet (see [Known Issues](#known-issues--recommendations)):
```

with:

```markdown
`Services/MLAnalysisService.swift` measures cheap on-device signals, `Services/MonsterClassifier.swift` turns them into monsters, and an optional Core ML blur model (`Services/BlurModelService.swift`; none is bundled yet) can take over the blur call:
```

```markdown
| Blur Beast | Laplacian-variance blur estimate | LongTake Leviathan | duration > 2 min |
```

with:

```markdown
| Blur Beast | bundled blur model when present, else Laplacian-variance estimate | LongTake Leviathan | duration > 2 min |
```

```markdown
Classification is behind a pluggable `PhotoClassifier`/`VideoClassifier` protocol (`Services/MediaClassifier.swift`), explicitly designed as a strategy-pattern seam for swapping in real Core ML models later.
```

with:

```markdown
Classification is a pure static enum (`MonsterClassifier`) over `MediaItem` and `MediaFingerprint`. The blur call goes through `BlurDecision`: the bundled model's answer when there is one, the Laplacian heuristic otherwise. `tools/coreml/README.md` has the model contract and the bar a trained model must clear.
```

and the Roadmap bullet:

```markdown
- Replace heuristic photo/video classifiers with real bundled Core ML models (`BlurClassifier.mlmodel`, `VideoQualityScorer.mlmodel`) — flagged with `// TODO` in `Services/MLAnalysisService.swift`.
```

with:

```markdown
- Train and bundle `BlurClassifier`: the runtime, the fallback and the acceptance gate are in place (`tools/coreml/README.md`). A video-quality model waits on a decision about which monster a blurry video should summon.
```

If a model shipped, change the last bullet to say so and drop "none is bundled yet" from the first replacement. Then:

```bash
python3 -I tools/ci/repo_guard.py
git add README.md
git commit -m "Describe the optional blur model in the README"
git push -u origin HEAD
```

## Not in this plan

- **A trained model.** See "What this plan delivers".
- **A video-quality model.** See the same section.
- **Blending the model and the heuristic.** A single rule is easier to evaluate and to roll back.
- **Apple's built-in aesthetics request** (`VNCalculateImageAestheticsScoresRequest`, iOS 18). It scores overall appeal and flags utility images, not blur, so it would answer a different question than the one the Blur Beast asks. It could feed a future "boring photo" monster.

## Self-review

- Spec coverage: "Core ML models with heuristics as fallback" is met by Tasks 1 to 3 (runtime and fallback, proven by `BlurModelServiceTests` and `BlurClassificationTests`) and Tasks 4 and 5 (how a model is made and admitted). The two things it cannot do (supply weights, define video quality) are named with their reasons.
- Placeholder scan: none; every code step carries its code.
- Type consistency: `BlurModelContract.modelName` (Task 1) is the name `BlurModelService.modelName` (Task 3) and the test (Task 3) assert; `MediaItem.modelBlurProbability` (Task 2) is set in Task 3's wiring and read by `BlurDecision` through the classifier; `BinaryMetrics`/`ModelAcceptance` (Task 1) are used by Task 4's evaluation test.
- Fallback contract: no code path reads a generated model class; the only way the model reaches the app is `Bundle.url(forResource:withExtension:)`, so deleting the file is a complete rollback.
