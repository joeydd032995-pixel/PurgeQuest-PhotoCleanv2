//
//  ThumbnailAnalysis.swift
//  PurgeQuest
//
//  What the scan measures about a photo, from ONE grayscale render of its thumbnail. The UIKit half
//  (`MLAnalysisService.thumbnailMetrics`) draws the picture into a 256x256 gray context and hands the
//  bytes here; everything below is pure Foundation, so the Linux harness and the real-photo benchmark
//  (tools/detection_bench) run the exact code the app does.
//
//    focus      0...100, higher is sharper. How much of the picture's fine detail survives a light
//               re-blur (Crete et al., "The blur effect: perception and estimation with a new
//               no-reference perceptual blur metric"): a blurry picture has little left to lose.
//    exposure   mean luminance, and the luminance the brightest 5% of the frame reaches.
//    signature  16x16 luminance grid, to confirm duplicate matches (see LumaSignature).
//
//  Why not the old rule (variance of a Laplacian on an 80x80 downsample, flagged under 9.0)? Measured
//  on 157 real photographs and blurred copies of them (tools/detection_bench), it flagged 0% of a 5 px
//  Gaussian blur and 2.5% of an 8 px one at 600 px, because the 80x80 downsample erases the very detail
//  that separates soft from sharp; it only ever fired on near-featureless frames. Re-blur loss at
//  256x256 with the line at 55 flags 75% of a 3 px blur, 99% of a 5 px one, and 51% / 97% of 15 / 31 px
//  motion blur, while flagging 1 of the 157 sharp originals (a hazy sunrise).
//

import Foundation

/// The measurements taken from one thumbnail.
nonisolated struct ThumbnailMetrics: Sendable, Equatable {
    /// 0...100, higher is sharper. Nil when the picture has too little structure to judge, which is
    /// not the same as blurry: a clear sky and a black frame have nothing to be out of focus.
    let focus: Double?
    /// Mean luminance, 0...1.
    let meanLuminance: Double
    /// The luminance the brightest 5% of the frame reaches, 0...1. A pocket shot is dark everywhere;
    /// a night scene is dark on average but not here.
    let highlightLuminance: Double
    /// 16x16 luminance signature for duplicate confirmation.
    let signature: LumaSignature
}

nonisolated enum ThumbnailAnalysis {

    /// Side of the square gray render the metrics expect.
    static let side = 256

    /// Focus below this reads as blurry. The lowest-scoring of 157 sharp photographs (a hazy sunrise)
    /// scored 53.7 and the next 61.9; 55 leaves the hazy one as the only sharp photo flagged.
    static let blurLine: Double = 55

    /// A picture whose neighbouring pixels differ by less than this on average (gray levels, summed over
    /// both directions) has nothing to measure focus on.
    static let minimumEdgeEnergy = 1.0

    /// Width of the box re-blur. Odd.
    static let reblurKernel = 9

    // MARK: - Entry point

    /// Nil unless `pixels` holds a whole `side` x `side` grid and `side` is a multiple of 32.
    static func metrics(grayscale pixels: [UInt8], side: Int = ThumbnailAnalysis.side) -> ThumbnailMetrics? {
        guard side >= 32, side % 32 == 0, pixels.count == side * side else { return nil }

        let cells = blockMeans(pixels, side: side, cellsPerSide: 32)
        let mean = cells.reduce(0, +) / Double(cells.count) / 255
        let sorted = cells.sorted()
        let highlight = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))] / 255

        let signatureSamples = blockMeans(pixels, side: side, cellsPerSide: LumaSignature.side).map { UInt8(min(255, max(0, $0.rounded()))) }
        guard let signature = LumaSignature(grayscale: signatureSamples) else { return nil }

        return ThumbnailMetrics(
            focus: focusScore(grayscale: pixels, side: side),
            meanLuminance: mean,
            highlightLuminance: highlight,
            signature: signature
        )
    }

    // MARK: - Focus

    /// 0...100 (higher is sharper), or nil when there is too little structure to judge.
    ///
    /// Each row and each column is blurred by a short box filter. Where the blur removes a lot of the
    /// neighbour-to-neighbour variation the picture was sharp; where it removes almost none the picture
    /// was already soft. The worse of the two directions counts, so motion blur along one axis is not
    /// averaged away by a crisp perpendicular one.
    static func focusScore(grayscale pixels: [UInt8], side: Int) -> Double? {
        guard side >= 16, pixels.count == side * side else { return nil }
        let vertical = variation(of: pixels, side: side, vertical: true)
        let horizontal = variation(of: pixels, side: side, vertical: false)

        let span = Double(side * (side - 1))
        let edgeEnergy = vertical.total / span + horizontal.total / span
        guard edgeEnergy >= minimumEdgeEnergy, vertical.total > 0, horizontal.total > 0 else { return nil }

        let blurV = (vertical.total - vertical.lost) / vertical.total
        let blurH = (horizontal.total - horizontal.lost) / horizontal.total
        return min(100, max(0, 100 * (1 - max(blurV, blurH))))
    }

    /// Summed neighbour differences along one direction (`total`), and how much of that a box re-blur
    /// takes away (`lost`: where a difference shrinks, by how much).
    private static func variation(of pixels: [UInt8], side: Int, vertical: Bool) -> (total: Double, lost: Double) {
        let kernel = reblurKernel
        let radius = kernel / 2
        var line = [Double](repeating: 0, count: side)
        var prefix = [Double](repeating: 0, count: side + 2 * radius + 1)
        var blurred = [Double](repeating: 0, count: side)
        var total = 0.0
        var lost = 0.0

        for l in 0..<side {
            for i in 0..<side { line[i] = Double(vertical ? pixels[i * side + l] : pixels[l * side + i]) }

            // Prefix sums over the line with its first and last values repeated `radius` times.
            var running = 0.0
            for i in 0..<(side + 2 * radius) {
                running += line[min(max(i - radius, 0), side - 1)]
                prefix[i + 1] = running
            }
            for i in 0..<side { blurred[i] = (prefix[i + kernel] - prefix[i]) / Double(kernel) }

            for i in 0..<(side - 1) {
                let d = abs(line[i + 1] - line[i])
                let blurredDifference = abs(blurred[i + 1] - blurred[i])
                total += d
                lost += max(0, d - blurredDifference)
            }
        }
        return (total, lost)
    }

    // MARK: - Block averages

    /// Mean of each `side / cellsPerSide` square block, row by row, in 0...255.
    private static func blockMeans(_ pixels: [UInt8], side: Int, cellsPerSide: Int) -> [Double] {
        let block = side / cellsPerSide
        var out = [Double](repeating: 0, count: cellsPerSide * cellsPerSide)
        for cy in 0..<cellsPerSide {
            for cx in 0..<cellsPerSide {
                var sum = 0
                for y in (cy * block)..<((cy + 1) * block) {
                    let row = y * side
                    for x in (cx * block)..<((cx + 1) * block) { sum += Int(pixels[row + x]) }
                }
                out[cy * cellsPerSide + cx] = Double(sum) / Double(block * block)
            }
        }
        return out
    }
}

// MARK: - Rules

/// The decisions the classifier makes from the measurements, as pure functions of plain numbers, so the
/// Linux harness can test them (MonsterClassifier itself needs UIKit types). Each threshold lives here
/// and nowhere else; MonsterClassifier and RoomTargeting restate them and tests pin the links.
nonisolated enum PhotoRules {

    /// Focus below `ThumbnailAnalysis.blurLine` is blurry.
    static var blurLine: Double { ThumbnailAnalysis.blurLine }

    /// A photo is dark when it is dark on average...
    static let darkLuminance: Double = 0.18
    /// ...and also dark where it is brightest. Mean luminance alone flags night scenes, silhouettes and
    /// low-key portraits, which are deliberate. On 157 real photographs the mean-only rule wrongly flagged
    /// the two with real highlights (their brightest 5% sat at 0.37 and 0.38) and this removes both, while
    /// flagging 99% of a frame underexposed 4.6 stops. Raise it to flag more, lower it to flag fewer.
    static let darkHighlight: Double = 0.30

    /// Taller and narrower than this is "saved from elsewhere", if it is also small (below).
    static let tallAspect: Double = 0.6
    /// Camera originals are big: a phone's 16:9 portrait photo is 9 MP and a vertical panorama more.
    /// Stories, reels and saved posts are 2 MP or so.
    static let tallDownloadMaxPixels = 4_000_000

    /// Enough recognized text to call a photo a document.
    static let denseTextCharacters = 300
    /// Many recognized regions also count, but only with real words behind them: a street of shop signs
    /// reads as many regions and a handful of letters.
    static let denseTextRegions = 6
    static let denseTextRegionCharacterFloor = 60

    static func isBlurry(focus: Double?) -> Bool {
        guard let focus else { return false }
        return focus < blurLine
    }

    static func isDark(luminance: Double?, highlight: Double?) -> Bool {
        guard let luminance, luminance < darkLuminance else { return false }
        guard let highlight else { return true }   // measured without highlights: the mean decides
        return highlight < darkHighlight
    }

    static func isTallDownload(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        return Double(width) / Double(height) < tallAspect && width * height <= tallDownloadMaxPixels
    }

    static func isDenseText(characters: Int, regions: Int) -> Bool {
        characters >= denseTextCharacters
            || (regions >= denseTextRegions && characters >= denseTextRegionCharacterFloor)
    }
}
