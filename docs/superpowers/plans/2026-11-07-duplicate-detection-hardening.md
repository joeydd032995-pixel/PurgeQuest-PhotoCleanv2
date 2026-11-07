# Duplicate Detection Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing perceptual-hash duplicate finder trustworthy: no false matches between unrelated pictures, no photo-with-video groups, honest burst detection, and tests that run on Linux as well as in Xcode.

**Architecture:** The engine in `DuplicateDetection.swift` is already pure and testable except for one UIKit enum. Make that file compile on Linux (conditional UIKit, a pure `DHash` that owns the bit order), register it with the Linux harness, then fix four demonstrated defects test-first: structureless hashes, photo/video mixing, single-linkage chaining, and undated bursts. The persisted hashes are untouched, so the fingerprint cache stays valid.

**Tech Stack:** Swift 5 language mode, Foundation, UIKit (conditionally), Swift Testing. No new dependencies.

**Roadmap item:** 2 of 4 ("Add real duplicate detection (perceptual hash / dHash)"). It is independent of the other three plans.

## What the code actually does today (verified against the tree, not the README)

The README says no duplicate-detection logic exists. It does, end to end:

- **Stage A, exact:** identical content hash, or identical size, dimensions, duration and capture second (`DuplicateDetectionEngine.findClusters`). `PhotoLibraryService.contentHash(for:)` hashes the first 256 KB of metadata-equal candidates only.
- **Stage B, near:** a 64-bit difference hash of the thumbnail (`MediaFingerprinter.dHash`, 9x8 grayscale), Hamming distance at most 10, grouped with union-find. Capture times then decide the cluster's kind (burst, edited, near).
- **Persistence:** `MediaFingerprintStore` / `MediaFingerprintRecord` cache hashes so repeated dives never re-hash.
- **Wiring:** `CombatViewModel.classifyAndGroup` builds the fingerprints, confirms exact candidates, and hands them to `MonsterClassifier.classify`.
- **Survivor ranking** is a suggestion only; the player decides every copy.

So this is not "add detection". It is "make the detection correct". Running the **original** engine from `git HEAD` and the new tests against it shows four real defects:

| # | Defect | Demonstrated by |
|---|---|---|
| 1 | Hashes with no structure match each other. A black frame and a blank wall both hash to `0`, distance 0, so the original engine returns `["black", "wall"] near` for two unrelated pictures. | A probe built from `git show HEAD:…/DuplicateDetection.swift`; `flatThumbnailsNeverClusterByShape` |
| 2 | Photos and videos can share a cluster. `[photo, video, video2]` came back as one group. | `photosAndVideosNeverShareACluster` |
| 3 | Union-find chains look-alikes: A is near B, B is near C, A and C are 16 bits apart, and all three merge. | `chainsOfLookAlikesSplitInsteadOfMerging` |
| 4 | A cluster with no capture dates is labelled a Burst Hydra (`span` defaults to 0). | `undatedCopiesAreNeverABurst` |

## Verification environment

- **Linux harness:** needs Swift 6.2 or newer (`https://download.swift.org/swift-6.2.1-release/ubuntu2404/swift-6.2.1-RELEASE/swift-6.2.1-RELEASE-ubuntu24.04.tar.gz` for Ubuntu 24.04). Run `SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh --filter DuplicateEngineTests`.
- **Xcode:** `xcodebuild -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug -destination 'platform=iOS Simulator,name=<an iOS 18+ iPhone>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:PurgeQuestTests/<Suite> test`, or `tools/ci/xcode-test.sh` for the whole target.
- **No Mac available:** push and read the "iOS Unit Tests" workflow on the pull request. Do not report an Xcode-only step as passed unless it ran.
- **Verified while writing this plan:** Tasks 1 to 3 were replayed from a clean copy of the repo on Swift 6.2.1 in two modes, the repository's own harness settings and the app's settings (Swift 5 language mode, default main-actor isolation, approachable-concurrency features). Each red phase failed for the reason stated and each green phase passed with no warnings. Tasks 4 and 5 (UIKit, `MonsterClassifier`) only had their edits applied to the real files and syntax-checked; they have **not** been compiled or run, and `MediaFingerprinterTests` renders real pixels, so run it first and read any failure before changing a threshold.

## Global Constraints

- iOS 18.0+ deployment target; Swift 5 language mode; the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- Fully offline, no third-party dependencies, recoverable deletion only (`tools/ci/repo_guard.py`).
- **Persisted hashes must not change.** `MediaFingerprintRecord.dHashBits` holds hashes computed by the current bit order. `DHash` reproduces that order exactly; the Task 4 test pins it.
- Files listed in `tools/swift_harness/run.sh` must be pure Foundation and must exist (`repo_guard.py` check 5 verifies the second part).
- New Swift files under `ios/PurgeQuest/` and `ios/PurgeQuestTests/` are picked up automatically. Do not edit `project.pbxproj`.
- Tests use Swift Testing; suites are `@MainActor`, as in `BestiaryTests.swift`.
- Commit messages are plain imperative sentences.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `ios/PurgeQuest/Services/DuplicateDetection.swift` | modify | `DHash`; conditional UIKit; informative-hash guard; media-kind separation; complete-linkage grouping; honest bursts |
| `ios/PurgeQuestTests/DuplicateEngineTests.swift` | create | Pure tests (run on Linux and in Xcode) |
| `tools/swift_harness/run.sh` | modify | Compile the engine and run its tests on Linux |
| `ios/PurgeQuestTests/MediaFingerprinterTests.swift` | create | Real-pixel tests for the UIKit half |
| `ios/PurgeQuest/Services/MonsterClassifier.swift` | modify | Album Echo explains itself as a repeated capture |
| `ios/PurgeQuestTests/ClusterReasonTests.swift` | create | Cluster explanation text |
| `README.md` | modify | Describe duplicate detection; adjust the roadmap |

---

### Task 1: A pure `DHash`, and the engine on the Linux harness

**Files:**
- Modify: `ios/PurgeQuest/Services/DuplicateDetection.swift`
- Modify: `tools/swift_harness/run.sh`
- Create: `ios/PurgeQuestTests/DuplicateEngineTests.swift`

**Interfaces:**
- Produces: `DHash.width` (9), `DHash.height` (8), `DHash.hash(grayscale: [UInt8]) -> UInt64?` (nil unless exactly 72 samples). Bit `n` (least significant first) is set when a sample is brighter than its right neighbour, reading the grid row by row. This is the order `MediaFingerprinter.dHash` has always used.

- [ ] **Step 1: Write the failing tests and register them**

Create `ios/PurgeQuestTests/DuplicateEngineTests.swift`:

```swift
//
//  DuplicateEngineTests.swift
//  PurgeQuestTests
//
//  Pure-Foundation tests for the duplicate engine. They also run on the Linux harness
//  (tools/swift_harness/run.sh), so nothing here may touch UIKit, SwiftData or Photos.
//

import Testing
import Foundation
@testable import PurgeQuest

/// Deterministic shuffling for the order-independence test.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@MainActor
struct DuplicateEngineTests {

    // MARK: - Helpers

    private static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A fingerprint captured `offset` seconds after the epoch (nil = no capture date).
    private func fingerprint(
        _ id: String,
        dHash: UInt64?,
        offset: TimeInterval? = 0,
        width: Int = 4000,
        height: Int = 3000,
        bytes: Int64 = 2_000_000,
        duration: Double = 0,
        hasEdits: Bool = false,
        contentHash: String? = nil
    ) -> MediaFingerprint {
        MediaFingerprint(
            assetID: id, byteSize: bytes,
            pixelWidth: width, pixelHeight: height,
            durationSeconds: duration,
            creationDate: offset.map { Self.epoch.addingTimeInterval($0) },
            isFavorite: false, isScreenshot: false,
            hasEdits: hasEdits, isScreenRecording: false,
            dHash: dHash, sharpness: nil, contentHash: contentHash
        )
    }

    // MARK: - DHash

    @Test func dHashNeedsExactlySeventyTwoSamples() {
        #expect(DHash.hash(grayscale: []) == nil)
        #expect(DHash.hash(grayscale: [UInt8](repeating: 0, count: 71)) == nil)
        #expect(DHash.hash(grayscale: [UInt8](repeating: 0, count: 73)) == nil)
        #expect(DHash.hash(grayscale: [UInt8](repeating: 0, count: 72)) != nil)
    }

    @Test func flatGridHashesToZero() {
        #expect(DHash.hash(grayscale: [UInt8](repeating: 128, count: 72)) == 0)
    }

    @Test func equalNeighboursDoNotSetABit() {
        // "Brighter than" is strict, so a plateau reads as 0.
        #expect(DHash.hash(grayscale: [UInt8](repeating: 90, count: 72)) == 0)
    }

    @Test func bitsFollowRowMajorOrderLeastSignificantFirst() {
        // Every row falls from left to right, so all 64 comparisons are "left > right".
        var falling: [UInt8] = []
        for _ in 0..<8 { falling += (0..<9).map { UInt8(200 - $0 * 10) } }
        #expect(DHash.hash(grayscale: falling) == UInt64.max)

        // Only the first comparison of the first row (bit 0).
        var first = [UInt8](repeating: 100, count: 72)
        first[0] = 150
        #expect(DHash.hash(grayscale: first) == 1)

        // Row 1, third comparison: bit 1 * 8 + 2 = 10.
        var middle = [UInt8](repeating: 100, count: 72)
        middle[1 * 9 + 2] = 150
        #expect(DHash.hash(grayscale: middle) == UInt64(1) << 10)

        // Last row, last comparison (x = 7 against x = 8): bit 63.
        var last = [UInt8](repeating: 100, count: 72)
        last[7 * 9 + 7] = 150
        #expect(DHash.hash(grayscale: last) == UInt64(1) << 63)
    }

    // New tests go above this line.
}
```

In `tools/swift_harness/run.sh` make three one-token additions. Each `old` text occurs once:

```text
Models/ColorTheme
```

becomes

```text
Models/ColorTheme Services/DuplicateDetection
```

```text
ThemePaletteTests
```

becomes

```text
ThemePaletteTests DuplicateEngineTests
```

and in the header comment

```text
AppearanceMode, ColorTheme
```

becomes

```text
AppearanceMode, ColorTheme, DuplicateDetection
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: FAIL to compile with `error: no such module 'UIKit'` in `DuplicateDetection.swift`. That is the point: the pure engine cannot yet leave the device.

- [ ] **Step 3: Make the file portable and add `DHash`**

In `ios/PurgeQuest/Services/DuplicateDetection.swift` replace the imports:

```swift
import Foundation
import UIKit

/// A lightweight, persistable fingerprint for one library asset.
```

with:

```swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A lightweight, persistable fingerprint for one library asset.
```

and replace the whole `MediaFingerprinter` section (from its `// MARK:` line to the end of the enum, just above `// Sorting helper so cluster output is deterministic for tests.`):

```swift
// MARK: - Fingerprint building (UIImage-dependent)

enum MediaFingerprinter {

    /// dHash (difference hash): downsample to 9×8 grayscale, compare each
    /// pixel with its right neighbor → 64 comparison bits.
    static func dHash(image: UIImage) -> UInt64? {
        guard let cg = image.cgImage else { return nil }
        let width = 9, height = 8
        guard let ctx = grayscaleContext(width: width, height: height) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)

        var hash: UInt64 = 0
        var bit = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                let left = pixels[y * width + x]
                let right = pixels[y * width + x + 1]
                if left > right { hash |= (1 << UInt64(bit)) }
                bit += 1
            }
        }
        return hash
    }

    private static func grayscaleContext(width: Int, height: Int) -> CGContext? {
        let cs = CGColorSpaceCreateDeviceGray()
        return CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
    }
}
```

with:

```swift
// MARK: - Perceptual hash

/// The pure half of the 64-bit difference hash. `MediaFingerprinter` renders a 9×8 grayscale
/// thumbnail and hands the bytes here, so the bit order, and with it every hash already stored in
/// `MediaFingerprintRecord`, is defined in exactly one place. Do not change it: stored hashes
/// would stop matching new ones.
enum DHash {
    static let width = 9
    static let height = 8

    /// Bit `n` (least significant first) is set when a pixel is brighter than its right
    /// neighbour, reading the 9×8 grid row by row. Nil unless exactly 72 samples are given.
    static func hash(grayscale pixels: [UInt8]) -> UInt64? {
        guard pixels.count == width * height else { return nil }
        var hash: UInt64 = 0
        var bit = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                if pixels[y * width + x] > pixels[y * width + x + 1] { hash |= (1 << UInt64(bit)) }
                bit += 1
            }
        }
        return hash
    }
}

// MARK: - Fingerprint building (UIImage-dependent)

#if canImport(UIKit)
enum MediaFingerprinter {

    /// dHash (difference hash): downsample to 9×8 grayscale, compare each
    /// pixel with its right neighbor → 64 comparison bits (bit order: see `DHash`).
    static func dHash(image: UIImage) -> UInt64? {
        guard let cg = image.cgImage else { return nil }
        guard let ctx = grayscaleContext(width: DHash.width, height: DHash.height) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: DHash.width, height: DHash.height))
        guard let data = ctx.data else { return nil }
        let count = DHash.width * DHash.height
        let samples = UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: count), count: count)
        return DHash.hash(grayscale: Array(samples))
    }

    private static func grayscaleContext(width: Int, height: Int) -> CGContext? {
        let cs = CGColorSpaceCreateDeviceGray()
        return CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
    }
}
#endif
```

`MediaFingerprinter.dHash` now draws the 9x8 grayscale grid exactly as before and hands the 72 bytes to `DHash`, so every hash already stored in `MediaFingerprintRecord` stays valid.

- [ ] **Step 4: Run them and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: PASS, four tests. Also run `python3 -I tools/ci/repo_guard.py`; it must report no `harness:` problems.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/DuplicateDetection.swift ios/PurgeQuestTests/DuplicateEngineTests.swift tools/swift_harness/run.sh
git commit -m "Make the duplicate engine portable and give the dHash bit order one home"
```

---

### Task 2: Pictures with no structure are never matched by shape

**Files:**
- Modify: `ios/PurgeQuest/Services/DuplicateDetection.swift`
- Modify: `ios/PurgeQuestTests/DuplicateEngineTests.swift`

**Interfaces:**
- Produces: `DuplicateDetectionEngine.minimumInformativeBits` (`nearSimilarityThreshold / 2 + 1`, which is 6) and `DuplicateDetectionEngine.isInformative(_ hash: UInt64) -> Bool` (at least 6 bits set and at least 6 clear).

Why 6: two hashes whose set bits total at most `nearSimilarityThreshold` are within the threshold of each other whatever the pictures are. Requiring more than half the threshold on each side removes every such automatic match. Natural photographs hash around 32 set bits.

- [ ] **Step 1: Add the failing tests**

In `ios/PurgeQuestTests/DuplicateEngineTests.swift`, insert the following immediately above the line `    // New tests go above this line.`:

```swift
    // MARK: - Hashes without structure

    @Test func informativeHashesNeedStructureOnBothSides() {
        #expect(!DuplicateDetectionEngine.isInformative(0))
        #expect(!DuplicateDetectionEngine.isInformative(UInt64.max))
        #expect(!DuplicateDetectionEngine.isInformative(0b1_1111))        // 5 bits set
        #expect(DuplicateDetectionEngine.isInformative(0b11_1111))        // 6 bits set
        #expect(DuplicateDetectionEngine.isInformative(UInt64.max >> 6))  // 58 set, 6 clear
        #expect(!DuplicateDetectionEngine.isInformative(UInt64.max >> 5)) // 59 set, 5 clear
        #expect(DuplicateDetectionEngine.isInformative(0xAAAA_5555_AAAA_5555))
    }

    @Test func flatThumbnailsNeverClusterByShape() {
        // Three different pictures that all hash to "nothing": a black frame, a white wall, a blank screen.
        let flats = [
            fingerprint("black", dHash: 0, offset: 0),
            fingerprint("wall", dHash: 0, offset: 86_400 * 3, bytes: 900_000),
            fingerprint("blank", dHash: UInt64.max, offset: 86_400 * 9, bytes: 700_000)
        ]
        #expect(DuplicateDetectionEngine.findClusters(in: flats).isEmpty)
    }

    @Test func nearlyFlatHashesCannotBridgeUnrelatedPictures() {
        // Two stray bits each: within 10 of one another, yet nothing like the same picture.
        let a = fingerprint("a", dHash: 0b0000_0011, offset: 0)
        let b = fingerprint("b", dHash: 0b1100_0000, offset: 100, bytes: 2_000_100)
        #expect(DuplicateDetectionEngine.hammingDistance(0b0000_0011, 0b1100_0000) == 4)
        #expect(DuplicateDetectionEngine.findClusters(in: [a, b]).isEmpty)
    }

    @Test func structuredLookAlikesStillCluster() {
        let base: UInt64 = 0xAAAA_5555_AAAA_5555
        let a = fingerprint("a", dHash: base, offset: 0)
        let b = fingerprint("b", dHash: base ^ 0b111, offset: 86_400 * 5, bytes: 2_000_333) // 3 bits apart
        let clusters = DuplicateDetectionEngine.findClusters(in: [a, b])
        #expect(clusters.map(\.memberIDs) == [["a", "b"]])
        #expect(clusters.first?.kind == .near)
    }
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: FAIL to compile with `type 'DuplicateDetectionEngine' has no member 'isInformative'`.

- [ ] **Step 3: Add the guard**

In `DuplicateDetection.swift` replace:

```swift
    /// Perceptual similarity threshold: ~10 of 64 bits may differ while
    /// images still read as the same capture.
    static let nearSimilarityThreshold = 10
```

with:

```swift
    /// Perceptual similarity threshold: ~10 of 64 bits may differ while
    /// images still read as the same capture.
    static let nearSimilarityThreshold = 10

    /// Fewest set (and fewest cleared) bits a hash needs before it may be matched by shape. Two
    /// hashes with at most `nearSimilarityThreshold` bits set between them are "near" whatever
    /// the pictures are, and that is every pair of flat, near-black or near-white thumbnails.
    static let minimumInformativeBits = nearSimilarityThreshold / 2 + 1

    /// True when the hash has enough structure to compare perceptually.
    static func isInformative(_ hash: UInt64) -> Bool {
        let set = hash.nonzeroBitCount
        return set >= minimumInformativeBits && 64 - set >= minimumInformativeBits
    }
```

and in `findClusters` replace:

```swift
        // Stage B — near: perceptual similarity via union-find over dHashes.
        let remaining = fingerprints.filter { !consumed.contains($0.assetID) && $0.dHash != nil }
        guard remaining.count >= 2 else { return clusters.sorted() }
```

with:

```swift
        // Stage B — near: perceptual similarity via union-find over dHashes. Hashes without
        // structure (flat frames) are left out: they would match every other flat frame.
        let remaining = fingerprints.filter { f in
            guard !consumed.contains(f.assetID), let hash = f.dHash else { return false }
            return isInformative(hash)
        }
        guard remaining.count >= 2 else { return clusters.sorted() }
```

- [ ] **Step 4: Run them and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: PASS, eight tests. A black frame, a white wall and a blank screen no longer group; two pictures that genuinely look alike still do.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/DuplicateDetection.swift ios/PurgeQuestTests/DuplicateEngineTests.swift
git commit -m "Stop matching flat thumbnails to each other by shape"
```

---

### Task 3: Groups hold only look-alikes, only of one kind, and bursts need dates

**Files:**
- Modify: `ios/PurgeQuest/Services/DuplicateDetection.swift`
- Modify: `ios/PurgeQuestTests/DuplicateEngineTests.swift`

**Interfaces:**
- Produces: `MediaFingerprint.isVideo` (`durationSeconds > 0`); near clusters are formed by greedy complete linkage (every pair in a group is within `nearSimilarityThreshold`), visited oldest first with the asset ID as the tie-break, separately for stills and for videos. `findClusters` keeps its signature and its sorted output.

- [ ] **Step 1: Pin today's behaviour first**

Insert above `    // New tests go above this line.` a characterization test. It feeds the engine the same situations `BestiaryTests` feeds the classifier, and must pass **before and after** the rewrite:

```swift
    @Test func familiarScenariosKeepTheirClusterKinds() {
        // The inputs BestiaryTests feeds the classifier: the engine must keep answering as before.
        var burst: [MediaFingerprint] = []
        for i in 0..<3 {
            let size = Int64(3_000_000 + i * 7_777)
            burst.append(fingerprint("burst\(i)", dHash: 0xF0F0, offset: TimeInterval(i), bytes: size))
        }
        #expect(DuplicateDetectionEngine.findClusters(in: burst).map(\.kind) == [.burst])

        let edited = [
            fingerprint("orig", dHash: 0xFF00_FF00_FF00_FF00, offset: 0, bytes: 4_000_000),
            fingerprint("edited", dHash: 0xFF00_FF00_FF00_FF00, offset: 60, width: 3000, height: 2000, bytes: 3_500_000)
        ]
        #expect(DuplicateDetectionEngine.findClusters(in: edited).map(\.kind) == [.edited])

        let day: TimeInterval = 86_400
        let echo = [
            fingerprint("old", dHash: 0x0F0F_0F0F_0F0F_0F0F, offset: -60 * day, bytes: 5_000_000),
            fingerprint("new", dHash: 0x0F0F_0F0F_0F0F_0F0F, offset: -5 * day, bytes: 5_000_100)
        ]
        #expect(DuplicateDetectionEngine.findClusters(in: echo).map(\.kind) == [.near])

        var hoard: [MediaFingerprint] = []
        for i in 0..<6 {
            let capturedAt = TimeInterval(i) * day
            let size = Int64(6_000_000 + i * 9_999)
            hoard.append(fingerprint("hoard\(i)", dHash: 0xAAAA_5555_AAAA_5555, offset: capturedAt, bytes: size))
        }
        let hoardClusters = DuplicateDetectionEngine.findClusters(in: hoard)
        #expect(hoardClusters.count == 1)
        #expect(hoardClusters.first?.memberIDs.count == 6)

        let twinA = fingerprint("a", dHash: nil, contentHash: "abc123")
        let twinB = fingerprint("b", dHash: nil, bytes: 2_000_001, contentHash: "abc123")
        #expect(DuplicateDetectionEngine.findClusters(in: [twinA, twinB]).map(\.kind) == [.exact])
    }
```

- [ ] **Step 2: Run it against the current engine**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: PASS, nine tests. This is the baseline: if it fails, your tree differs from the one this plan was written against; stop and reconcile before continuing.

- [ ] **Step 3: Add the tests that expose the defects**

Insert above `    // New tests go above this line.`:

```swift
    // MARK: - Cluster integrity

    @Test func chainsOfLookAlikesSplitInsteadOfMerging() {
        let a: UInt64 = 0xAAAA_5555_AAAA_5555
        let b = a ^ 0x0000_0000_0000_00FF   // 8 bits from a
        let c = b ^ 0x0000_0000_00FF_0000   // 8 bits from b, 16 from a
        #expect(DuplicateDetectionEngine.hammingDistance(a, b) == 8)
        #expect(DuplicateDetectionEngine.hammingDistance(b, c) == 8)
        #expect(DuplicateDetectionEngine.hammingDistance(a, c) == 16)

        let prints = [
            fingerprint("a", dHash: a, offset: 0),
            fingerprint("b", dHash: b, offset: 86_400 * 4, bytes: 2_000_100),
            fingerprint("c", dHash: c, offset: 86_400 * 8, bytes: 2_000_200)
        ]
        // a~b and b~c, but a and c are not look-alikes, so c must not ride along.
        #expect(DuplicateDetectionEngine.findClusters(in: prints).map(\.memberIDs) == [["a", "b"]])
    }

    @Test func photosAndVideosNeverShareACluster() {
        let h: UInt64 = 0xFF00_FF00_FF00_FF00
        let photo = fingerprint("photo", dHash: h, offset: 0)
        let video = fingerprint("video", dHash: h, offset: 60, bytes: 9_000_000, duration: 12)
        #expect(DuplicateDetectionEngine.findClusters(in: [photo, video]).isEmpty)

        let twin = fingerprint("video2", dHash: h, offset: 120, bytes: 9_000_400, duration: 12)
        let clusters = DuplicateDetectionEngine.findClusters(in: [photo, video, twin])
        #expect(clusters.map(\.memberIDs) == [["video", "video2"]])
    }

    @Test func undatedCopiesAreNeverABurst() {
        let h: UInt64 = 0xFF00_FF00_FF00_FF00
        let a = fingerprint("a", dHash: h, offset: nil)
        let b = fingerprint("b", dHash: h, offset: nil, bytes: 2_000_100)
        let clusters = DuplicateDetectionEngine.findClusters(in: [a, b])
        #expect(clusters.count == 1)
        #expect(clusters.first?.kind == .near)
    }

    @Test func datedCopiesSecondsApartAreABurst() {
        let h: UInt64 = 0xFF00_FF00_FF00_FF00
        var prints: [MediaFingerprint] = []
        for i in 0..<3 {
            let size = Int64(2_000_000 + i * 17)
            prints.append(fingerprint("shot\(i)", dHash: h, offset: TimeInterval(i), bytes: size))
        }
        #expect(DuplicateDetectionEngine.findClusters(in: prints).first?.kind == .burst)
    }

    @Test func clustersDoNotDependOnInputOrder() {
        let base: UInt64 = 0xAAAA_5555_AAAA_5555
        var prints: [MediaFingerprint] = []
        for i in 0..<5 {
            let capturedAt = TimeInterval(i) * 7_200
            let size = Int64(3_000_000 + i * 11)
            prints.append(fingerprint("x\(i)", dHash: base ^ UInt64(i), offset: capturedAt, bytes: size))
        }
        for i in 0..<4 {
            let capturedAt = TimeInterval(i) * 7_200
            let size = Int64(5_000_000 + i * 13)
            prints.append(fingerprint("y\(i)", dHash: ~base ^ UInt64(i), offset: capturedAt, bytes: size))
        }
        var rng = SeededGenerator(seed: 42)
        let forward = DuplicateDetectionEngine.findClusters(in: prints)
        #expect(forward.count == 2)
        #expect(DuplicateDetectionEngine.findClusters(in: Array(prints.reversed())) == forward)
        #expect(DuplicateDetectionEngine.findClusters(in: prints.shuffled(using: &rng)) == forward)
    }
```

- [ ] **Step 4: Run them and confirm exactly three fail**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: FAIL with 4 issues in 3 tests, 14 tests in all:
- `chainsOfLookAlikesSplitInsteadOfMerging`: got `[["a", "b", "c"]]`, wanted `[["a", "b"]]`.
- `photosAndVideosNeverShareACluster`: two issues; the pair came back as a cluster and the three-way run returned `[["photo", "video", "video2"]]`.
- `undatedCopiesAreNeverABurst`: got `.burst`, wanted `.near`.

`datedCopiesSecondsApartAreABurst` and `clustersDoNotDependOnInputOrder` pass already; they guard the rewrite.

- [ ] **Step 5: Rewrite stage B**

In `DuplicateDetection.swift` make three edits.

Add the media-kind property. Replace:

```swift
    var longEdge: Int { max(pixelWidth, pixelHeight) }
```

with:

```swift
    var longEdge: Int { max(pixelWidth, pixelHeight) }
    /// Videos carry a duration; stills do not.
    var isVideo: Bool { durationSeconds > 0 }
```

Replace the whole stage-B region of `findClusters`, through the end of `kind(for:)` (the block you edited in Task 2 up to the line before `/// Finds metadata-equal candidate groups`):

```swift
        // Stage B — near: perceptual similarity via union-find over dHashes. Hashes without
        // structure (flat frames) are left out: they would match every other flat frame.
        let remaining = fingerprints.filter { f in
            guard !consumed.contains(f.assetID), let hash = f.dHash else { return false }
            return isInformative(hash)
        }
        guard remaining.count >= 2 else { return clusters.sorted() }

        var parent = Dictionary(uniqueKeysWithValues: remaining.map { ($0.assetID, $0.assetID) })
        func find(_ id: String) -> String {
            var root = id
            while parent[root] != root { root = parent[root]! }
            return root
        }
        func union(_ a: String, _ b: String) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in 0..<remaining.count {
            for j in (i + 1)..<remaining.count {
                let a = remaining[i], b = remaining[j]
                guard let ha = a.dHash, let hb = b.dHash else { continue }
                if hammingDistance(ha, hb) <= nearSimilarityThreshold {
                    union(a.assetID, b.assetID)
                }
            }
        }

        var grouped: [String: [MediaFingerprint]] = [:]
        for f in remaining { grouped[find(f.assetID), default: []].append(f) }

        for group in grouped.values where group.count >= 2 {
            clusters.append(DuplicateCluster(memberIDs: ordered(group.map(\.assetID), in: fingerprints), kind: kind(for: group)))
        }

        return clusters.sorted()
    }

    /// Burst when every member lands in one short window; edited when
    /// dimensions differ or a member carries edits; otherwise near.
    private static func kind(for group: [MediaFingerprint]) -> DuplicateClusterKind {
        let dates = group.compactMap(\.creationDate).sorted()
        let span = (dates.count >= 2) ? dates.last!.timeIntervalSince(dates.first!) : 0
        if span <= burstWindow { return .burst }
        let dims = Set(group.map { "\($0.pixelWidth)x\($0.pixelHeight)" })
        if dims.count > 1 || group.contains(where: \.hasEdits) { return .edited }
        return .near
    }
```

with:

```swift
        // Stage B — near: perceptual similarity. Hashes without structure (flat frames) are left
        // out, photos and videos are never mixed, and every pair in a cluster must be within the
        // threshold (complete linkage), so a chain of look-alikes splits instead of merging.
        let candidates = fingerprints.filter { f in
            guard !consumed.contains(f.assetID), let hash = f.dHash else { return false }
            return isInformative(hash)
        }
        for videos in [false, true] {
            let pool = candidates.filter { $0.isVideo == videos }
            for group in nearGroups(in: pool) {
                clusters.append(DuplicateCluster(
                    memberIDs: ordered(group.map(\.assetID), in: fingerprints),
                    kind: kind(for: group)
                ))
            }
        }
        return clusters.sorted()
    }

    /// Greedy complete-linkage grouping over dHashes. Members are visited oldest first (the asset
    /// ID breaks ties), so the result does not depend on the order of the input.
    private static func nearGroups(in pool: [MediaFingerprint]) -> [[MediaFingerprint]] {
        var groups: [[MediaFingerprint]] = []
        for f in pool.sorted(by: { capturedEarlier($0, $1) }) {
            guard let hash = f.dHash else { continue }
            let home = groups.firstIndex { group in
                group.allSatisfy { member in
                    member.dHash.map { hammingDistance($0, hash) <= nearSimilarityThreshold } ?? false
                }
            }
            if let home { groups[home].append(f) } else { groups.append([f]) }
        }
        return groups.filter { $0.count >= 2 }
    }

    private static func capturedEarlier(_ a: MediaFingerprint, _ b: MediaFingerprint) -> Bool {
        let da = a.creationDate ?? .distantFuture
        let db = b.creationDate ?? .distantFuture
        return da != db ? da < db : a.assetID < b.assetID
    }

    /// Burst when every member has a capture time and they all land in one short window; edited
    /// when dimensions differ or a member carries edits; otherwise near. Undated assets say
    /// nothing about proximity, so they can never make a burst.
    private static func kind(for group: [MediaFingerprint]) -> DuplicateClusterKind {
        let dates = group.compactMap(\.creationDate).sorted()
        if dates.count == group.count, let first = dates.first, let last = dates.last,
           last.timeIntervalSince(first) <= burstWindow {
            return .burst
        }
        let dims = Set(group.map { "\($0.pixelWidth)x\($0.pixelHeight)" })
        if dims.count > 1 || group.contains(where: \.hasEdits) { return .edited }
        return .near
    }
```

Make ties deterministic in `ordered`. Replace:

```swift
        return ids.sorted { (byID[$0]?.creationDate ?? .distantFuture) < (byID[$1]?.creationDate ?? .distantFuture) }
```

with:

```swift
        return ids.sorted { a, b in
            let da = byID[a]?.creationDate ?? .distantFuture
            let db = byID[b]?.creationDate ?? .distantFuture
            return da != db ? da < db : a < b
        }
```

Two details matter. `pool.sorted(by: { capturedEarlier($0, $1) })` is a closure on purpose: under the app's default main-actor isolation, passing the static method as a bare function reference to `sorted(by:)` warns today and is an error in Swift 6 mode. And the test expressions use local constants because chained integer arithmetic inside initializer calls times out the type checker under the app's settings.

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests`
Expected: PASS, 14 tests. Then run the whole Linux suite, `SWIFT_BIN=… tools/swift_harness/run.sh`; every suite that passed before must still pass. (On a checkout without the `Art/` folder, `ModularManifestFileTests` and `LookRecolorTests` fail identically before and after; that is not caused by this change.)

- [ ] **Step 7: Commit**

```bash
git add ios/PurgeQuest/Services/DuplicateDetection.swift ios/PurgeQuestTests/DuplicateEngineTests.swift
git commit -m "Keep duplicate groups to look-alikes of one kind and call a burst only when dated"
```

---

### Task 4: Pin the pixel rendering that stored hashes depend on

**Files:**
- Create: `ios/PurgeQuestTests/MediaFingerprinterTests.swift`

These are guard tests for behaviour that already exists, so they should pass on the first run.

- [ ] **Step 1: Write the tests**

Create `ios/PurgeQuestTests/MediaFingerprinterTests.swift`:

```swift
//
//  MediaFingerprinterTests.swift
//  PurgeQuestTests
//
//  The UIKit half of duplicate detection: real pixels in, 64-bit hash out. The bit order itself
//  is pinned by DuplicateEngineTests (DHash); these tests pin the rendering in front of it, so a
//  change that silently alters stored hashes fails here.
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct MediaFingerprinterTests {

    /// An 8-bit grayscale image holding exactly these samples.
    private func grayImage(width: Int, height: Int, samples: [UInt8]) throws -> UIImage {
        let provider = try #require(CGDataProvider(data: Data(samples) as CFData))
        let cgImage = try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        return UIImage(cgImage: cgImage)
    }

    /// Two rising ramps with a sharp drop between them, drawn at any size. `mirrored` flips left and right.
    private func sawtooth(size: CGSize, mirrored: Bool = false, lift: Double = 0) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let width = Int(size.width)
            for x in 0..<width {
                var t = Double(x) / Double(width) * 2
                t -= t.rounded(.down)
                if mirrored { t = 1 - t }
                UIColor(white: min(1, 0.2 + 0.6 * t + lift), alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 1, height: Int(size.height)))
            }
        }
    }

    private func distance(_ a: UIImage, _ b: UIImage) throws -> Int {
        let hashA = try #require(MediaFingerprinter.dHash(image: a))
        let hashB = try #require(MediaFingerprinter.dHash(image: b))
        return DuplicateDetectionEngine.hammingDistance(hashA, hashB)
    }

    @Test func aNineByEightImageHashesToItsOwnSamples() throws {
        // No scaling happens at 9x8, so the hash must equal DHash over the same bytes.
        var samples: [UInt8] = []
        for i in 0..<72 { samples.append(UInt8((i * 37) % 251)) }
        let image = try grayImage(width: 9, height: 8, samples: samples)
        #expect(MediaFingerprinter.dHash(image: image) == DHash.hash(grayscale: samples))
    }

    @Test func theSameSceneAtTwoSizesHashesAlike() throws {
        let large = sawtooth(size: CGSize(width: 640, height: 480))
        let small = sawtooth(size: CGSize(width: 320, height: 240))
        #expect(try distance(large, small) <= DuplicateDetectionEngine.nearSimilarityThreshold)
    }

    @Test func aBrighterCopyHashesAlike() throws {
        let original = sawtooth(size: CGSize(width: 480, height: 360))
        let brighter = sawtooth(size: CGSize(width: 480, height: 360), lift: 0.12)
        #expect(try distance(original, brighter) <= DuplicateDetectionEngine.nearSimilarityThreshold)
    }

    @Test func aMirroredSceneHashesApart() throws {
        let original = sawtooth(size: CGSize(width: 480, height: 360))
        let mirrored = sawtooth(size: CGSize(width: 480, height: 360), mirrored: true)
        #expect(try distance(original, mirrored) > DuplicateDetectionEngine.nearSimilarityThreshold)
    }

    @Test func aFlatPictureHashesToNothingAndIsNotMatchable() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let flat = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        let hash = try #require(MediaFingerprinter.dHash(image: flat))
        #expect(hash == 0)
        #expect(!DuplicateDetectionEngine.isInformative(hash))
    }

    @Test func anImageWithoutPixelsHasNoHash() {
        #expect(MediaFingerprinter.dHash(image: UIImage()) == nil)
    }
}
```

- [ ] **Step 2: Run them**

Run: `xcodebuild … -only-testing:PurgeQuestTests/MediaFingerprinterTests test`
Expected: PASS, six tests.

If `aNineByEightImageHashesToItsOwnSamples` fails, the refactor in Task 1 changed how stored hashes are computed: stop and fix Task 1, because every fingerprint already in users' stores would stop matching. If one of the *scene* tests fails, print the distance it measured before touching anything; the scenes are simple on purpose (two rising ramps with a sharp drop), so a surprising distance usually means the rendering, not the threshold, changed.

- [ ] **Step 3: Commit**

```bash
git add ios/PurgeQuestTests/MediaFingerprinterTests.swift
git commit -m "Test that the thumbnail hash survives resizing and brightening and tells scenes apart"
```

---

### Task 5: An Album Echo says why it appeared

**Files:**
- Modify: `ios/PurgeQuest/Services/MonsterClassifier.swift`
- Create: `ios/PurgeQuestTests/ClusterReasonTests.swift`

`ClassificationReason.repeatedCapture` ("Saved more than once on different days") is defined and never produced, so an Album Echo's "Why did this appear?" line only says "Nearly identical to another capture".

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/ClusterReasonTests.swift`:

```swift
//
//  ClusterReasonTests.swift
//  PurgeQuestTests
//
//  A duplicate group explains itself: the Album Echo says it was saved again on another day.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ClusterReasonTests {

    private func copies(daysApart: Double, exactContent: Bool = false) -> (items: [MediaItem], prints: [MediaFingerprint]) {
        let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var items: [MediaItem] = []
        var prints: [MediaFingerprint] = []
        for i in 0..<2 {
            let date = epoch.addingTimeInterval(Double(i) * daysApart * 86_400)
            let size = Int64(5_000_000 + i * 100)
            let item = MediaItem(
                id: "copy\(i)", kind: .photo, creationDate: date, pixelWidth: 4000, pixelHeight: 3000,
                durationSeconds: 0, estimatedBytes: size, isFavorite: false, playbackStyle: 1
            )
            items.append(item)
            prints.append(MediaFingerprint(
                assetID: item.id, byteSize: size, pixelWidth: 4000, pixelHeight: 3000, durationSeconds: 0,
                creationDate: date, isFavorite: false, isScreenshot: false, hasEdits: false,
                isScreenRecording: false, dHash: 0x0F0F_0F0F_0F0F_0F0F, sharpness: nil,
                contentHash: exactContent ? "same" : nil
            ))
        }
        return (items, prints)
    }

    @Test func anEchoAcrossWeeksSaysItWasSavedAgain() {
        let echo = copies(daysApart: 55)
        let verdict = MonsterClassifier.classify(items: echo.items, fingerprints: echo.prints).classifications["copy0"]
        #expect(verdict?.monsterType == .albumEcho)
        #expect(verdict?.reasons == [.nearDuplicateCluster, .repeatedCapture])
        #expect(verdict?.whyText.contains("Saved more than once on different days") == true)
    }

    @Test func otherDuplicatesDoNotClaimToBeRepeatedCaptures() {
        let pair = copies(daysApart: 0.04, exactContent: true)
        let verdict = MonsterClassifier.classify(items: pair.items, fingerprints: pair.prints).classifications["copy0"]
        #expect(verdict?.reasons == [.exactBinaryMatch])
    }
}
```

- [ ] **Step 2: Run them and confirm one fails**

Run: `xcodebuild … -only-testing:PurgeQuestTests/ClusterReasonTests test`
Expected: `anEchoAcrossWeeksSaysItWasSavedAgain` fails (`reasons` is `[.nearDuplicateCluster]`); `otherDuplicatesDoNotClaimToBeRepeatedCaptures` passes.

- [ ] **Step 3: Produce the reason**

In `MonsterClassifier.classify`, replace:

```swift
            let type = monsterType(for: cluster, members: memberFPs)
            let reasons = reasons(for: cluster)
```

with:

```swift
            let type = monsterType(for: cluster, members: memberFPs)
            let reasons = reasons(for: cluster, type: type)
```

and replace the helper:

```swift
    private static func reasons(for cluster: DuplicateCluster) -> [ClassificationReason] {
        switch cluster.kind {
        case .exact:  return [.exactBinaryMatch]
        case .burst:  return [.burstGroup]
        case .edited: return [.editedVariant]
        case .near:   return [.nearDuplicateCluster]
        }
    }
```

with:

```swift
    private static func reasons(for cluster: DuplicateCluster, type: MonsterType) -> [ClassificationReason] {
        var reasons: [ClassificationReason]
        switch cluster.kind {
        case .exact:  reasons = [.exactBinaryMatch]
        case .burst:  reasons = [.burstGroup]
        case .edited: reasons = [.editedVariant]
        case .near:   reasons = [.nearDuplicateCluster]
        }
        // The same capture turning up again weeks later.
        if type == .albumEcho { reasons.append(.repeatedCapture) }
        return reasons
    }
```

- [ ] **Step 4: Run the tests, then the whole target**

Run: `xcodebuild … -only-testing:PurgeQuestTests/ClusterReasonTests test`, then `tools/ci/xcode-test.sh`.
Expected: PASS everywhere, including the existing `BestiaryTests` duplicate scenarios.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/MonsterClassifier.swift ios/PurgeQuestTests/ClusterReasonTests.swift
git commit -m "Explain an Album Echo as a capture saved again on another day"
```

---

### Task 6: Document it and open the pull request

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Describe duplicate detection**

Insert a section before `### RPG progression` by replacing:

```markdown
### RPG progression
```

with:

```markdown
### Duplicate detection (on-device)
Two stages in `Services/DuplicateDetection.swift`: **exact** (identical content hash, or identical size, dimensions, duration and capture second) and **near** (a 64-bit dHash of the thumbnail; copies within 10 differing bits). Near matching ignores thumbnails with no structure (black frames, blank walls), never mixes photos with videos, and requires every pair in a group to look alike, so a chain of look-alikes splits instead of merging. The oldest copy is the group's representative and the suggested keeper is only a suggestion: the player decides each copy.

### RPG progression
```

- [ ] **Step 2: Point the roadmap at what is left**

Replace this Roadmap bullet:

```markdown
- Actual duplicate-photo detection, to make the existing "Duplicate Dragon" quest/achievement completable (see Known Issue #1).
```

with:

```markdown
- Library-wide duplicate matching: copies are paired within each dive's batch of unseen photos, so twins far apart in the library are not yet matched (see `docs/superpowers/plans/2026-11-07-duplicate-detection-hardening.md`, "Not in this plan").
```

The other three plans edit different Roadmap bullets, so this one is unaffected by the order they land in.

- [ ] **Step 3: Run the checks and open the pull request**

```bash
python3 -I tools/ci/repo_guard.py
SWIFT_BIN=… tools/swift_harness/run.sh --filter DuplicateEngineTests
git add README.md
git commit -m "Describe duplicate detection in the README"
git push -u origin HEAD
```

In the pull request description, include the four defects table and the before/after of `DuplicateEngineTests`. Watch the "iOS Unit Tests" and "Repo guard" workflows.

## Not in this plan

- **Library-wide matching.** The finder compares only the assets in a dive's batch (the oldest 150 unseen, `CombatViewModel.initialFetchLimit`). Bursts, edits and re-saves captured near each other are found; a twin far away in the library is not, so an Album Echo is found only when both copies fall in the same batch. Fixing that means fingerprinting a wider window, pulling copies that are outside the batch into a group card (their thumbnails and `MediaItem`s must be built on demand), and deciding how a copy the player already kept should appear. Those are product and battery decisions, not hardening, so they deserve their own spec.
- **Tuning `nearSimilarityThreshold`.** It stays at 10 of 64 bits. Measure it on a real library before changing it.
- **"Exact" without a content hash.** When a content hash cannot be read (iCloud-only media), metadata equality still forms an `.exact` cluster whose reason says "Identical file content". The chance of a false match is negligible but the sentence is stronger than the evidence.

## Self-review

- Spec coverage: "real duplicate detection (perceptual hash / dHash)" is answered by the verified-state section (it exists) plus Tasks 1 to 5 (the four demonstrated defects, the pixel guard, the explanation). The one genuine gap, library scope, is named in "Not in this plan" with the reason it is separate.
- Placeholder scan: none; every code step carries its code.
- Type consistency: `DHash` (Task 1) is used by `MediaFingerprinter` and `MediaFingerprinterTests`; `isInformative` (Task 2) is used by Task 3's stage B and Task 4's flat-picture test; `isVideo` (Task 3) is used only inside the engine.
- Cross-plan: `ContentReachabilityTests` (content-reachability plan) builds duplicate witnesses from `0xAAAA_5555_AAAA_5555`, which is informative (32 set bits), so it keeps passing after Task 2.
