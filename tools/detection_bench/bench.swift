// Real-photo benchmark for PurgeQuest's duplicate finder and photo-quality rules.
// Built and run by tools/detection_bench/run.sh against the app's own pure sources; it never
// reimplements the engine. Input comes from prepare.py (see that file for what it approximates).
import Foundation

// MARK: - Input

struct Sample {
    let index: Int
    let name: String
    let group: Int
    let kind: String
    let srcW: Int
    let srcH: Int
}

/// Grid layout of one record. Keep in step with GRIDS in prepare.py.
enum Grid {
    static let sizes: [(w: Int, h: Int)] = [(9, 8), (16, 16), (32, 32), (80, 80), (128, 128), (256, 256)]
    static let recordSize = sizes.reduce(0) { $0 + $1.w * $1.h }
    static func offset(of grid: Int) -> Int { sizes[..<grid].reduce(0) { $0 + $1.w * $1.h } }
    static let g9x8 = 0, g16 = 1, g32 = 2, g80 = 3, g128 = 4, g256 = 5
}

struct Dataset {
    let samples: [Sample]
    let data: [UInt8]

    init(directory: String) throws {
        let manifest = try String(contentsOfFile: directory + "/manifest.tsv", encoding: .utf8)
        var rows: [Sample] = []
        for line in manifest.split(separator: "\n").dropFirst() {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            rows.append(Sample(index: Int(f[0])!, name: f[1], group: Int(f[2])!, kind: f[3], srcW: Int(f[4])!, srcH: Int(f[5])!))
        }
        samples = rows
        data = [UInt8](try Data(contentsOf: URL(fileURLWithPath: directory + "/features.bin")))
        precondition(data.count == rows.count * Grid.recordSize, "features.bin does not match manifest.tsv")
    }

    func gray(_ sample: Sample, grid: Int) -> [UInt8] {
        let g = Grid.sizes[grid]
        let start = sample.index * Grid.recordSize + Grid.offset(of: grid)
        return Array(data[start..<(start + g.w * g.h)])
    }
}

// MARK: - Output helpers

/// ThumbnailAnalysis on a sample's 256x256 grid, the same call the app makes. Computed once per sample.
nonisolated(unsafe) var metricsCache: [Int: ThumbnailMetrics] = [:]
func metrics(of sample: Sample, in ds: Dataset) -> ThumbnailMetrics? {
    if let hit = metricsCache[sample.index] { return hit }
    guard let m = ThumbnailAnalysis.metrics(grayscale: ds.gray(sample, grid: Grid.g256), side: 256) else { return nil }
    metricsCache[sample.index] = m
    return m
}

func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "n/a" : String(format: "%5.1f%%", 100 * Double(a) / Double(b)) }
func line(_ s: String = "") { print(s) }
func header(_ s: String) { line(); line("== " + s) }
func seconds<T>(_ body: () -> T) -> (T, Double) {
    let t0 = DispatchTime.now().uptimeNanoseconds
    let r = body()
    return (r, Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9)
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Duplicate benchmark

let dedupeKinds: Set<String> = ["orig", "copy", "syn_bright", "syn_resave", "syn_crop"]

func fingerprint(_ s: Sample, in ds: Dataset, withSignature: Bool) -> MediaFingerprint {
    let hash = DHash.hash(grayscale: ds.gray(s, grid: Grid.g9x8))
    let signature = withSignature ? metrics(of: s, in: ds)?.signature : nil
    // Dates: scenes days apart, variants a minute after their original. Kinds are not under test.
    let date = Date(timeIntervalSince1970: 1_600_000_000 + Double(s.group) * 259_200 + (s.kind == "orig" ? 0 : 60))
    return MediaFingerprint(
        assetID: String(s.index), byteSize: Int64(1_000_000 + s.index), pixelWidth: s.srcW, pixelHeight: s.srcH,
        durationSeconds: 0, creationDate: date, isFavorite: false, isScreenshot: false, hasEdits: false,
        isScreenRecording: false, dHash: hash, sharpness: nil, contentHash: nil, isVideo: false, signature: signature
    )
}

struct PairScore {
    var truePositive = 0, falsePositive = 0, truePairs = 0
    var missedByKind: [String: (found: Int, total: Int)] = [:]
    var falsePairs: [(String, String)] = []
    var falseClusterImages = 0
}

func scorePairs(_ clusters: [DuplicateCluster], samples: [Sample]) -> PairScore {
    let byID = Dictionary(uniqueKeysWithValues: samples.map { (String($0.index), $0) })
    var score = PairScore()
    // Ground truth: every unordered pair sharing a scene.
    var groups: [Int: [Sample]] = [:]
    for s in samples { groups[s.group, default: []].append(s) }
    for members in groups.values { score.truePairs += members.count * (members.count - 1) / 2 }

    var together = Set<String>()
    for c in clusters {
        let m = c.memberIDs.compactMap { byID[$0] }
        var impure = false
        for i in 0..<m.count {
            for j in (i + 1)..<max(i + 1, m.count) {
                if m[i].group == m[j].group { score.truePositive += 1; together.insert("\(m[i].index)-\(m[j].index)") }
                else { score.falsePositive += 1; impure = true; score.falsePairs.append((m[i].name + ":" + m[i].kind, m[j].name + ":" + m[j].kind)) }
            }
        }
        if impure { score.falseClusterImages += m.count }
    }
    // Recall per variant kind: is the variant clustered with its group's original?
    let originals = Dictionary(uniqueKeysWithValues: samples.filter { $0.kind == "orig" }.map { ($0.group, $0) })
    for s in samples where s.kind != "orig" {
        guard let o = originals[s.group] else { continue }
        let key = o.index < s.index ? "\(o.index)-\(s.index)" : "\(s.index)-\(o.index)"
        var e = score.missedByKind[s.kind] ?? (0, 0)
        e.total += 1
        if together.contains(key) { e.found += 1 }
        score.missedByKind[s.kind] = e
    }
    return score
}

func report(_ title: String, _ score: PairScore, seconds: Double) {
    let predicted = score.truePositive + score.falsePositive
    line("  \(title)")
    line("    pair precision \(pct(score.truePositive, predicted))   pair recall \(pct(score.truePositive, score.truePairs))   false pairs \(score.falsePositive)   images in impure clusters \(score.falseClusterImages)   (\(String(format: "%.1f", seconds * 1000)) ms)")
    let kinds = score.missedByKind.keys.sorted()
    line("    variant found with its original: " + kinds.map { "\($0) \(pct(score.missedByKind[$0]!.found, score.missedByKind[$0]!.total))" }.joined(separator: "   "))
}

func duplicateBenchmark(_ ds: Dataset) {
    header("Duplicate finder on real photos (DuplicateDetectionEngine.findClusters)")
    let pool = ds.samples.filter { dedupeKinds.contains($0.kind) }
    line("  \(pool.count) images: \(pool.filter { $0.kind == "orig" }.count) distinct scenes + \(pool.count - pool.filter { $0.kind == "orig" }.count) edited copies")

    // Separability of the 64-bit dHash itself.
    let originals = pool.filter { $0.kind == "orig" }
    let hashes = originals.map { DHash.hash(grayscale: ds.gray($0, grid: Grid.g9x8))! }
    var diffScene: [Int] = []
    for i in 0..<hashes.count { for j in (i + 1)..<hashes.count { diffScene.append(DuplicateDetectionEngine.hammingDistance(hashes[i], hashes[j])) } }
    diffScene.sort()
    func cumul(_ xs: [Int], upTo t: Int) -> Int { xs.filter { $0 <= t }.count }
    line("  different-scene pairs: \(diffScene.count), closest \(diffScene.first ?? -1) bits, median \(diffScene[diffScene.count / 2]) bits")
    line("    pairs within 6/8/10/12 bits: \([6, 8, 10, 12].map { String(cumul(diffScene, upTo: $0)) }.joined(separator: " / "))")
    let origByGroup = Dictionary(uniqueKeysWithValues: originals.map { ($0.group, $0) })
    var sameByKind: [String: [Int]] = [:]
    for s in pool where s.kind != "orig" {
        guard let o = origByGroup[s.group] else { continue }
        let a = DHash.hash(grayscale: ds.gray(o, grid: Grid.g9x8))!, b = DHash.hash(grayscale: ds.gray(s, grid: Grid.g9x8))!
        sameByKind[s.kind, default: []].append(DuplicateDetectionEngine.hammingDistance(a, b))
    }
    for k in sameByKind.keys.sorted() {
        let d = sameByKind[k]!.sorted()
        line("  same-scene \(k): n=\(d.count) median \(d[d.count / 2]) bits, 90th pct \(d[Int(Double(d.count) * 0.9)]), within 10 bits \(pct(cumul(d, upTo: 10), d.count))")
    }

    // The engine, whole set in one batch, then the app's 150-asset batches, with and without the signature.
    var rng = SplitMix64(state: 7)
    let groupIDs = Array(Set(pool.map(\.group))).sorted()
    for (label, withSignature) in [("dHash only (rule before the signature)", false), ("dHash + 16x16 luminance signature (shipped now)", true)] {
        line()
        line("  [\(label)]")
        let fps = pool.map { fingerprint($0, in: ds, withSignature: withSignature) }
        let (clusters, t) = seconds { DuplicateDetectionEngine.findClusters(in: fps) }
        report("whole set as one batch", scorePairs(clusters, samples: pool), seconds: t)

        // The app's batches are 150 assets: draw many such batches and average.
        var batchRng = SplitMix64(state: 7)
        var tp = 0, fp = 0, truth = 0
        for _ in 0..<40 {
            let chosen = Set(groupIDs.shuffled(using: &batchRng).prefix(40))
            var batch = pool.filter { chosen.contains($0.group) }.shuffled(using: &batchRng)
            if batch.count > 150 { batch = Array(batch.prefix(150)) }
            let s = scorePairs(DuplicateDetectionEngine.findClusters(in: batch.map { fingerprint($0, in: ds, withSignature: withSignature) }), samples: batch)
            tp += s.truePositive; fp += s.falsePositive; truth += s.truePairs
        }
        line("    40 random batches of up to 150: precision \(pct(tp, tp + fp))  recall \(pct(tp, truth))  false pairs \(fp)")
    }
    _ = rng
}

// MARK: - Quality benchmark (the rules the classifier applies to a thumbnail)

/// The shipped blur rule: variance of a 4-neighbour Laplacian on an 80x80 luminance grid
/// (MLAnalysisService.sharpnessVariance), flagged below MonsterClassifier.blurSharpness.
func shippedSharpness(_ g: [UInt8], width: Int, height: Int) -> Double {
    var values: [Double] = []
    values.reserveCapacity((width - 2) * (height - 2))
    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            let c = Double(g[y * width + x])
            let v = Double(g[(y - 1) * width + x]) + Double(g[(y + 1) * width + x]) + Double(g[y * width + x - 1]) + Double(g[y * width + x + 1]) - 4 * c
            values.append(v)
        }
    }
    let mean = values.reduce(0, +) / Double(values.count)
    return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
}

func shippedLuminance(_ g: [UInt8]) -> Double { g.reduce(0) { $0 + Double($1) } / Double(g.count) / 255 }

func qualityBenchmark(_ ds: Dataset) {
    header("Photo-quality rules on real photos: shipped rule vs ThumbnailAnalysis (what the app runs now)")
    let kinds = Array(Set(ds.samples.map(\.kind))).sorted()
    func pad(_ k: String) -> String { k.padding(toLength: 11, withPad: " ", startingAt: 0) }

    line("  BLUR. 'orig' are sharp photographs (a flag is a false positive); blur_N / motion_N are degraded copies (a flag is a hit).")
    line("    shipped: Laplacian variance on 80x80 < 9.0      now: focus score on 256x256 < \(ThumbnailAnalysis.blurLine) (flat frames are not judged)")
    let sharpKinds = ["orig", "syn_bright", "syn_resave", "syn_crop"]
    for k in kinds where sharpKinds.contains(k) || k.hasPrefix("blur_") || k.hasPrefix("motion_") {
        let rows = ds.samples.filter { $0.kind == k }
        let old = rows.filter { shippedSharpness(ds.gray($0, grid: Grid.g80), width: 80, height: 80) < 9.0 }.count
        let new = rows.filter { (metrics(of: $0, in: ds)?.focus ?? 100) < ThumbnailAnalysis.blurLine }.count
        let unjudged = rows.filter { metrics(of: $0, in: ds)?.focus == nil }.count
        line("    \(pad(k)) shipped \(pct(old, rows.count))   now \(pct(new, rows.count))   (n=\(rows.count), not judged: \(unjudged))")
    }

    line("  DARK. 'orig'/'syn_*'/'copy' are ordinary photographs (a flag is a false positive); dark_N are underexposed copies (a flag is a hit).")
    line("    shipped: mean luminance < 0.18      now: mean < 0.18 and the brightest 5% of the frame < 0.30")
    for k in kinds where sharpKinds.contains(k) || k == "copy" || k.hasPrefix("dark_") {
        let rows = ds.samples.filter { $0.kind == k }
        let old = rows.filter { shippedLuminance(ds.gray($0, grid: Grid.g16)) < 0.18 }.count
        let new = rows.filter { s in
            guard let m = metrics(of: s, in: ds) else { return false }
            return m.meanLuminance < 0.18 && m.highlightLuminance < 0.30
        }.count
        line("    \(pad(k)) shipped \(pct(old, rows.count))   now \(pct(new, rows.count))   (n=\(rows.count))")
    }

    // Cost of the measurement itself.
    let probe = Array(ds.samples.prefix(300))
    let (_, t) = seconds { for s in probe { _ = ThumbnailAnalysis.metrics(grayscale: ds.gray(s, grid: Grid.g256), side: 256) } }
    line("  cost: ThumbnailAnalysis.metrics on a 256x256 grid, \(String(format: "%.2f", t / Double(probe.count) * 1000)) ms per photo (release build, this machine)")
}

// MARK: - Engine scaling

func scalingBenchmark() {
    header("Engine cost as the batch grows (random informative hashes, 1 planted twin per 50 images)")
    for n in [150, 1_000, 5_000, 20_000] {
        var rng = SplitMix64(state: 42)
        var fps: [MediaFingerprint] = []
        for i in 0..<n {
            var h = UInt64.random(in: 0...UInt64.max, using: &rng)
            if i % 50 == 49, let twin = fps.last?.dHash { h = twin ^ (1 << UInt64(i % 64)) }
            fps.append(MediaFingerprint(
                assetID: "a\(i)", byteSize: Int64(1_000 + i), pixelWidth: 4032, pixelHeight: 3024, durationSeconds: 0,
                creationDate: Date(timeIntervalSince1970: 1_600_000_000 + Double(i) * 3_600), isFavorite: false,
                isScreenshot: false, hasEdits: false, isScreenRecording: false, dHash: h, sharpness: nil, contentHash: nil, isVideo: false))
        }
        let (clusters, t) = seconds { DuplicateDetectionEngine.findClusters(in: fps) }
        line("  n=\(String(n).padding(toLength: 6, withPad: " ", startingAt: 0)) \(String(format: "%9.1f", t * 1000)) ms   clusters \(clusters.count)")
    }
}

// MARK: - Entry point

let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: bench <prepared-dir> [dedupe|quality|scaling]"); exit(2) }
let only = args.count > 2 ? args[2] : "all"
let dataset = try Dataset(directory: args[1])
if only == "all" || only == "dedupe" { duplicateBenchmark(dataset) }
if only == "all" || only == "quality" { qualityBenchmark(dataset) }
if only == "all" || only == "scaling" { scalingBenchmark() }
