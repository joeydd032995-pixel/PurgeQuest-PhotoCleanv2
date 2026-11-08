//
//  DuplicateDetection.swift
//  PurgeQuest
//
//  Two-stage duplicate pipeline (rollout stage 1):
//    Stage A — exact: metadata-equal candidates confirmed by a partial
//              content hash (computed by PhotoLibraryService, cached).
//    Stage B — near: dHash perceptual fingerprints clustered by similarity
//              and time proximity (bursts vs edited variants vs echoes).
//
//  The engine is pure over MediaFingerprint so it stays fully unit-testable;
//  UIImage work lives in `MediaFingerprinter`. Nothing here chooses a
//  survivor — ranking only produces a suggestion the player confirms.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A lightweight, persistable fingerprint for one library asset.
struct MediaFingerprint: Sendable, Equatable {
    let assetID: String
    let byteSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let durationSeconds: Double
    let creationDate: Date?
    let isFavorite: Bool
    let isScreenshot: Bool
    let hasEdits: Bool
    let isScreenRecording: Bool
    /// 64-bit perceptual hash of the thumbnail (nil when no thumbnail).
    let dHash: UInt64?
    /// Laplacian-variance sharpness of the thumbnail (higher = sharper).
    let sharpness: Double?
    /// Partial SHA-256 of the primary resource (nil unless computed).
    let contentHash: String?

    var longEdge: Int { max(pixelWidth, pixelHeight) }

    func withContentHash(_ hash: String) -> MediaFingerprint {
        MediaFingerprint(
            assetID: assetID, byteSize: byteSize,
            pixelWidth: pixelWidth, pixelHeight: pixelHeight,
            durationSeconds: durationSeconds, creationDate: creationDate,
            isFavorite: isFavorite, isScreenshot: isScreenshot,
            hasEdits: hasEdits, isScreenRecording: isScreenRecording,
            dHash: dHash, sharpness: sharpness, contentHash: hash
        )
    }
}

enum DuplicateClusterKind: String, Codable, Sendable {
    case exact
    case burst
    case edited
    case near
}

struct DuplicateCluster: Sendable, Equatable {
    /// Member asset IDs, oldest capture first.
    let memberIDs: [String]
    let kind: DuplicateClusterKind
}

enum DuplicateDetectionEngine {

    /// Hamming distance between two 64-bit perceptual hashes.
    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

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

    /// Maximum capture-date span (seconds) for a cluster to count as a burst.
    static let burstWindow: TimeInterval = 3

    /// Capture-date span (seconds) beyond which an echo across time is
    /// recognized (the same image saved on different days).
    static let echoSpan: TimeInterval = 30 * 86_400

    /// Capture-date span (seconds) within which repeated saves count as
    /// downloads rather than album echoes.
    static let sameDaySpan: TimeInterval = 86_400

    /// Minimum cluster size for Hoard Hydra.
    static let hoardSize = 6

    // MARK: - Clustering

    /// Finds duplicate clusters across the given fingerprints.
    /// Stage A groups exact matches; Stage B clusters the rest by perceptual
    /// similarity (time proximity only shapes the cluster's kind).
    static func findClusters(in fingerprints: [MediaFingerprint]) -> [DuplicateCluster] {
        var clusters: [DuplicateCluster] = []
        var consumed = Set<String>()

        // Stage A — exact: identical content hash, or identical metadata when
        // no hash is available (bytes, dimensions, duration, capture second).
        var exactBuckets: [String: [MediaFingerprint]] = [:]
        for f in fingerprints where f.mediaKindSupportsDuplication {
            let key = exactKey(for: f)
            exactBuckets[key, default: []].append(f)
        }
        for group in exactBuckets.values where group.count >= 2 {
            clusters.append(DuplicateCluster(memberIDs: ordered(group.map(\.assetID), in: fingerprints), kind: .exact))
            group.forEach { consumed.insert($0.assetID) }
        }

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

    /// Finds metadata-equal candidate groups that still need a content hash
    /// to confirm — Stage A of the pipeline, keeping IO bounded.
    static func metadataExactCandidates(in fingerprints: [MediaFingerprint]) -> [[MediaFingerprint]] {
        var buckets: [String: [MediaFingerprint]] = [:]
        for f in fingerprints {
            buckets[metadataKey(for: f), default: []].append(f)
        }
        return buckets.values.filter { $0.count >= 2 }
    }

    private static func metadataKey(for f: MediaFingerprint) -> String {
        let second = f.creationDate.map { Int($0.timeIntervalSince1970) } ?? -1
        return "meta:\(f.byteSize):\(f.pixelWidth)x\(f.pixelHeight):\(Int(f.durationSeconds.rounded())):\(second)"
    }

    private static func exactKey(for f: MediaFingerprint) -> String {
        if let hash = f.contentHash { return "hash:\(hash)" }
        return metadataKey(for: f)
    }

    private static func ordered(_ ids: [String], in fingerprints: [MediaFingerprint]) -> [String] {
        let byID = Dictionary(uniqueKeysWithValues: fingerprints.map { ($0.assetID, $0) })
        return ids.sorted { (byID[$0]?.creationDate ?? .distantFuture) < (byID[$1]?.creationDate ?? .distantFuture) }
    }

    // MARK: - Survivor ranking

    /// Ranks the likely best copy: favorites first, then resolution,
    /// sharpness, and finally byte size. A suggestion only — the player
    /// always confirms explicitly.
    static func recommendedSurvivor(in members: [MediaFingerprint]) -> String? {
        guard let best = members.max(by: { score($0) < score($1) }) else { return nil }
        return best.assetID
    }

    private static func score(_ f: MediaFingerprint) -> Double {
        var s = 0.0
        if f.isFavorite { s += 10_000 }
        s += Double(f.pixelWidth * f.pixelHeight) / 100_000
        if let sharp = f.sharpness { s += min(sharp, 200) }
        s += Double(f.byteSize) / 100_000_000
        return s
    }
}

private extension MediaFingerprint {
    /// Live Photos pair a still with a motion resource; treat them as
    /// duplicate-capable regardless of kind since the paired file is separate.
    var mediaKindSupportsDuplication: Bool { true }
}

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

// Sorting helper so cluster output is deterministic for tests.
extension Array where Element == DuplicateCluster {
    func sorted() -> [DuplicateCluster] {
        sorted { lhs, rhs in
            if lhs.memberIDs != rhs.memberIDs { return lhs.memberIDs.lexicographicallyPrecedes(rhs.memberIDs) }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }
}
