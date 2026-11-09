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
    /// Focus score of the thumbnail, 0...100 (higher = sharper). See ThumbnailAnalysis.
    let sharpness: Double?
    /// Partial SHA-256 of the primary resource (nil unless computed).
    let contentHash: String?
    /// True for videos. The app passes the asset's real media type: a broken video can report a
    /// duration of zero, so when the kind is known it must not be guessed from the duration.
    let isVideo: Bool
    /// 16x16 luminance signature of the thumbnail. When both copies have one, a near match must also
    /// agree on the picture itself, not just on the 64-bit shape. Not persisted: it is rebuilt from the
    /// thumbnail on every scan, so the stored dHash cache stays valid.
    let signature: LumaSignature?

    init(
        assetID: String, byteSize: Int64, pixelWidth: Int, pixelHeight: Int, durationSeconds: Double,
        creationDate: Date?, isFavorite: Bool, isScreenshot: Bool, hasEdits: Bool, isScreenRecording: Bool,
        dHash: UInt64?, sharpness: Double?, contentHash: String?, isVideo: Bool? = nil,
        signature: LumaSignature? = nil
    ) {
        self.assetID = assetID
        self.byteSize = byteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.creationDate = creationDate
        self.isFavorite = isFavorite
        self.isScreenshot = isScreenshot
        self.hasEdits = hasEdits
        self.isScreenRecording = isScreenRecording
        self.dHash = dHash
        self.sharpness = sharpness
        self.contentHash = contentHash
        // Without an explicit kind, a duration means a video.
        self.isVideo = isVideo ?? (durationSeconds > 0)
        self.signature = signature
    }

    var longEdge: Int { max(pixelWidth, pixelHeight) }

    func withContentHash(_ hash: String) -> MediaFingerprint {
        MediaFingerprint(
            assetID: assetID, byteSize: byteSize,
            pixelWidth: pixelWidth, pixelHeight: pixelHeight,
            durationSeconds: durationSeconds, creationDate: creationDate,
            isFavorite: isFavorite, isScreenshot: isScreenshot,
            hasEdits: hasEdits, isScreenRecording: isScreenRecording,
            dHash: dHash, sharpness: sharpness, contentHash: hash, isVideo: isVideo,
            signature: signature
        )
    }
}

/// A 16x16 luminance fingerprint that confirms what the 64-bit dHash only suggests.
///
/// A dHash keeps just the sign of each horizontal gradient on a 9x8 grid, which is cheap and robust
/// but discards almost everything: two different low-contrast pictures can land a few bits apart, and
/// a mild crop can push two copies of one picture past the threshold. The correlation of the
/// luminance grids themselves is independent of both failure modes, so requiring the two to agree
/// removes the first kind of mistake and lets a looser shape distance recover the second.
nonisolated struct LumaSignature: Sendable, Equatable {
    static let side = 16
    static let sampleCount = side * side

    /// Pictures whose luminance varies less than this (standard deviation in 0...255 gray levels) have
    /// no structure to correlate. Sensor noise and JPEG blocking live below it.
    static let minimumContrast = 2.0

    /// Zero-mean, unit-length samples. All zeros for a flat picture, which correlates with nothing.
    let vector: [Float]

    /// Nil unless exactly 256 samples (16 rows of 16) are given.
    init?(grayscale pixels: [UInt8]) {
        guard pixels.count == Self.sampleCount else { return nil }
        let n = Double(pixels.count)
        let mean = pixels.reduce(0.0) { $0 + Double($1) } / n
        let centered = pixels.map { Double($0) - mean }
        let energy = centered.reduce(0.0) { $0 + $1 * $1 }
        let deviation = (energy / n).squareRoot()
        if deviation < Self.minimumContrast {
            vector = [Float](repeating: 0, count: Self.sampleCount)
        } else {
            let norm = energy.squareRoot()
            vector = centered.map { Float($0 / norm) }
        }
    }

    /// True when the picture is too flat to say anything about.
    var isFlat: Bool { !vector.contains { $0 != 0 } }

    /// Pearson correlation of the two luminance grids: 1 for the same picture, whatever its brightness
    /// or contrast; about 0 for unrelated pictures; 0 whenever either side is flat.
    func correlation(with other: LumaSignature) -> Double {
        var sum = 0.0
        for i in 0..<Self.sampleCount { sum += Double(vector[i]) * Double(other.vector[i]) }
        return sum
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

    /// Perceptual similarity threshold when only the dHash is available: ~10 of 64 bits may differ
    /// while images still read as the same capture.
    static let nearSimilarityThreshold = 10

    /// With a luminance signature on both sides the shape may drift further (a mild crop moves a dHash
    /// by 8 to 13 bits), but only while the pictures themselves correlate.
    static let confirmedSimilarityThreshold = 14

    /// Smallest 16x16 luminance correlation that confirms a near match.
    ///
    /// Measured on INRIA CopyDays (157 scenes, 366,796 image pairs, `tools/detection_bench`): the old
    /// dHash-only line (10 bits) wrongly paired 64 images of different scenes and found 84.9% of
    /// phone-style edits (re-saves, brightening, a mild crop); 14 bits with correlation 0.88 wrongly
    /// paired 1 and found 91.4%. At 15 bits the false pairs climb to 4.
    static let minimumCorrelation = 0.88

    /// True when two assets read as the same picture. With a signature on both sides the shape must be
    /// within `confirmedSimilarityThreshold` and the pictures must correlate; otherwise the dHash alone
    /// decides, at the stricter `nearSimilarityThreshold`.
    static func areNear(_ a: MediaFingerprint, _ b: MediaFingerprint) -> Bool {
        guard let ha = a.dHash, let hb = b.dHash else { return false }
        let distance = hammingDistance(ha, hb)
        if let sa = a.signature, let sb = b.signature {
            return distance <= confirmedSimilarityThreshold && sa.correlation(with: sb) >= minimumCorrelation
        }
        return distance <= nearSimilarityThreshold
    }

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
        // Built once: ordering a cluster's members needs each one's capture date. A repeated asset ID
        // keeps its first fingerprint instead of trapping.
        let byID = Dictionary(fingerprints.map { ($0.assetID, $0) }, uniquingKeysWith: { first, _ in first })

        // Stage A — exact: identical content hash, or identical metadata when
        // no hash is available (bytes, dimensions, duration, capture second).
        var exactBuckets: [String: [MediaFingerprint]] = [:]
        for f in fingerprints where f.mediaKindSupportsDuplication {
            let key = exactKey(for: f)
            exactBuckets[key, default: []].append(f)
        }
        for group in exactBuckets.values where group.count >= 2 {
            clusters.append(DuplicateCluster(memberIDs: ordered(group.map(\.assetID), by: byID), kind: .exact))
            group.forEach { consumed.insert($0.assetID) }
        }

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
                    memberIDs: ordered(group.map(\.assetID), by: byID),
                    kind: kind(for: group)
                ))
            }
        }
        return clusters.sorted()
    }

    /// Greedy complete-linkage grouping. Members are visited oldest first (the asset ID breaks ties), so
    /// the result does not depend on the order of the input: each one joins the first group, in the
    /// order groups were opened, whose every member it is near, or opens a group of its own.
    ///
    /// The answer is the one a scan of every group would give, found without that scan. Each item's
    /// earlier look-alikes are collected in one tight pass over the raw hashes, and only groups that
    /// hold one of them can possibly accept it, since acceptance needs every member to be a
    /// look-alike. For a library of mostly unrelated pictures that turns the per-item work from
    /// "compare against every open group" into "compare against a few".
    private static func nearGroups(in pool: [MediaFingerprint]) -> [[MediaFingerprint]] {
        let ordered = pool.sorted(by: { capturedEarlier($0, $1) })
        let count = ordered.count
        guard count >= 2 else { return [] }

        // Nothing farther apart than this can be near, so it is the cheap pre-filter for `areNear`.
        let radius = max(nearSimilarityThreshold, confirmedSimilarityThreshold)
        let hashes = ordered.map { $0.dHash ?? 0 }
        var lookAlikes = [[Int]](repeating: [], count: count)
        hashes.withUnsafeBufferPointer { h in
            for i in 1..<count {
                let hi = h[i]
                var found: [Int] = []
                for j in 0..<i where (h[j] ^ hi).nonzeroBitCount <= radius && areNear(ordered[i], ordered[j]) {
                    found.append(j)
                }
                lookAlikes[i] = found
            }
        }

        var groups: [[Int]] = []
        var groupOf = [Int](repeating: -1, count: count)
        for i in 0..<count {
            var home = -1
            if !lookAlikes[i].isEmpty {
                let near = Set(lookAlikes[i])
                for g in Set(lookAlikes[i].map { groupOf[$0] }).sorted() where groups[g].allSatisfy({ near.contains($0) }) {
                    home = g
                    break
                }
            }
            if home >= 0 {
                groups[home].append(i)
                groupOf[i] = home
            } else {
                groupOf[i] = groups.count
                groups.append([i])
            }
        }
        return groups.filter { $0.count >= 2 }.map { $0.map { ordered[$0] } }
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

    /// Finds metadata-equal candidate groups that still need a content hash
    /// to confirm — Stage A of the pipeline, keeping IO bounded.
    static func metadataExactCandidates(in fingerprints: [MediaFingerprint]) -> [[MediaFingerprint]] {
        var buckets: [String: [MediaFingerprint]] = [:]
        for f in fingerprints {
            buckets[metadataKey(for: f), default: []].append(f)
        }
        return buckets.values.filter { $0.count >= 2 }
    }

    /// Exact copies are of one kind: a still and a video never share a key.
    private static func kindTag(for f: MediaFingerprint) -> String {
        f.isVideo ? "video" : "still"
    }

    private static func metadataKey(for f: MediaFingerprint) -> String {
        let second = f.creationDate.map { Int($0.timeIntervalSince1970) } ?? -1
        return "meta:\(kindTag(for: f)):\(f.byteSize):\(f.pixelWidth)x\(f.pixelHeight):\(Int(f.durationSeconds.rounded())):\(second)"
    }

    private static func exactKey(for f: MediaFingerprint) -> String {
        if let hash = f.contentHash { return "hash:\(kindTag(for: f)):\(hash)" }
        return metadataKey(for: f)
    }

    private static func ordered(_ ids: [String], by byID: [String: MediaFingerprint]) -> [String] {
        ids.sorted { a, b in
            let da = byID[a]?.creationDate ?? .distantFuture
            let db = byID[b]?.creationDate ?? .distantFuture
            return da != db ? da < db : a < b
        }
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
        if let sharp = f.sharpness { s += min(max(sharp, 0), 100) }
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
