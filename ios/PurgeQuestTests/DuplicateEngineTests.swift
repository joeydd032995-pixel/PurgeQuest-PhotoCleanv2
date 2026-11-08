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

    // New tests go above this line.
}
