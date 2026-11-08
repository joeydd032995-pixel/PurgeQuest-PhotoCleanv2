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
        contentHash: String? = nil,
        isVideo: Bool? = nil
    ) -> MediaFingerprint {
        MediaFingerprint(
            assetID: id, byteSize: bytes,
            pixelWidth: width, pixelHeight: height,
            durationSeconds: duration,
            creationDate: offset.map { Self.epoch.addingTimeInterval($0) },
            isFavorite: false, isScreenshot: false,
            hasEdits: hasEdits, isScreenRecording: false,
            dHash: dHash, sharpness: nil, contentHash: contentHash,
            isVideo: isVideo
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

    // MARK: - The media kind an asset really has

    @Test func aVideoThatReportsNoDurationIsStillAVideo() {
        // A broken video can report a duration of zero; judged by duration alone it would be a still.
        let h: UInt64 = 0xFF00_FF00_FF00_FF00
        let photo = fingerprint("photo", dHash: h, offset: 0)
        let broken = fingerprint("broken", dHash: h, offset: 60, bytes: 9_000_000, duration: 0, isVideo: true)
        #expect(broken.isVideo)
        #expect(DuplicateDetectionEngine.findClusters(in: [photo, broken]).isEmpty)
    }

    @Test func aStillAndAVideoAreNeverExactCopies() {
        // Same size, shape and capture second, and neither has a duration: only the kind differs.
        let still = fingerprint("still", dHash: nil, offset: 0, isVideo: false)
        let video = fingerprint("video", dHash: nil, offset: 0, isVideo: true)
        #expect(DuplicateDetectionEngine.findClusters(in: [still, video]).isEmpty)

        // Nor does a shared content hash make them copies of one another.
        let hashedStill = fingerprint("hashedStill", dHash: nil, offset: 0, contentHash: "same", isVideo: false)
        let hashedVideo = fingerprint("hashedVideo", dHash: nil, offset: 5, bytes: 3, contentHash: "same", isVideo: true)
        #expect(DuplicateDetectionEngine.findClusters(in: [hashedStill, hashedVideo]).isEmpty)
    }

    @Test func twoBrokenCopiesOfOneVideoStillGroupAsVideos() {
        let a = fingerprint("a", dHash: nil, offset: 0, duration: 0, contentHash: "same", isVideo: true)
        let b = fingerprint("b", dHash: nil, offset: 5, bytes: 2_000_001, duration: 0, contentHash: "same", isVideo: true)
        let clusters = DuplicateDetectionEngine.findClusters(in: [a, b])
        #expect(clusters.map(\.memberIDs) == [["a", "b"]])
        #expect(clusters.first?.kind == .exact)
    }

    @Test func withoutAnExplicitKindTheDurationDecides() {
        #expect(fingerprint("clip", dHash: nil, duration: 12).isVideo)
        #expect(!fingerprint("still", dHash: nil, duration: 0).isVideo)
    }

    @Test func copyingAFingerprintKeepsItsKind() {
        let broken = fingerprint("broken", dHash: nil, duration: 0, isVideo: true)
        #expect(broken.withContentHash("abc").isVideo)
    }

    // New tests go above this line.
}
