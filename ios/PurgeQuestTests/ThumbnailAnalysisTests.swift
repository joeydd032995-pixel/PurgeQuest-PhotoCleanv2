//
//  ThumbnailAnalysisTests.swift
//  PurgeQuestTests
//
//  Pure-Foundation tests for the focus, exposure and signature measurements. They also run on the
//  Linux harness (tools/swift_harness/run.sh), so nothing here may touch UIKit, SwiftData or Photos.
//  The pictures are synthetic and built in code: no fixture files.
//

import Testing
import Foundation
@testable import PurgeQuest

private struct PictureRandom: RandomNumberGenerator {
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
struct ThumbnailAnalysisTests {

    private let side = ThumbnailAnalysis.side

    // MARK: - Synthetic pictures

    /// A scene with hard edges everywhere: overlapping rectangles of random brightness.
    private func scene(seed: UInt64) -> [UInt8] {
        var rng = PictureRandom(seed: seed)
        var pixels = [UInt8](repeating: 120, count: side * side)
        for _ in 0..<70 {
            let w = Int(rng.next() % 90) + 12, h = Int(rng.next() % 90) + 12
            let x0 = Int(rng.next() % UInt64(side - w)), y0 = Int(rng.next() % UInt64(side - h))
            let value = UInt8(rng.next() % 200 + 30)
            for y in y0..<(y0 + h) { for x in x0..<(x0 + w) { pixels[y * side + x] = value } }
        }
        return pixels
    }

    /// Box blur applied `passes` times in each direction; three passes read as a Gaussian.
    private func blurred(_ pixels: [UInt8], radius: Int, passes: Int = 3) -> [UInt8] {
        var current = pixels.map(Double.init)
        for _ in 0..<passes {
            for horizontal in [true, false] {
                var next = current
                for a in 0..<side {
                    for b in 0..<side {
                        var sum = 0.0
                        for k in -radius...radius {
                            let c = min(max(b + k, 0), side - 1)
                            sum += horizontal ? current[a * side + c] : current[c * side + a]
                        }
                        let v = sum / Double(2 * radius + 1)
                        if horizontal { next[a * side + b] = v } else { next[b * side + a] = v }
                    }
                }
                current = next
            }
        }
        return current.map { UInt8(max(0, min(255, $0.rounded()))) }
    }

    private func transposed(_ pixels: [UInt8]) -> [UInt8] {
        var out = pixels
        for y in 0..<side { for x in 0..<side { out[x * side + y] = pixels[y * side + x] } }
        return out
    }

    private func gradient(from: Double, to: Double) -> [UInt8] {
        (0..<(side * side)).map { i in
            let t = Double(i % side) / Double(side - 1)
            return UInt8((from + (to - from) * t).rounded())
        }
    }

    private func focus(_ pixels: [UInt8]) -> Double? { ThumbnailAnalysis.focusScore(grayscale: pixels, side: side) }

    // MARK: - Focus

    @Test func focusNeedsAWholeSquareGrid() {
        #expect(ThumbnailAnalysis.focusScore(grayscale: [], side: side) == nil)
        #expect(ThumbnailAnalysis.focusScore(grayscale: [UInt8](repeating: 0, count: side * side - 1), side: side) == nil)
        #expect(ThumbnailAnalysis.metrics(grayscale: [UInt8](repeating: 0, count: 100), side: side) == nil)
        #expect(ThumbnailAnalysis.metrics(grayscale: [UInt8](repeating: 0, count: 33 * 33), side: 33) == nil)
    }

    @Test func aSharpSceneScoresHigh() {
        for seed in 1...4 as ClosedRange<UInt64> {
            let score = focus(scene(seed: seed))
            #expect((score ?? 0) > 75, "seed \(seed): \(String(describing: score))")
        }
    }

    @Test func blurringLowersTheScoreStepByStep() {
        let sharp = scene(seed: 5)
        let scores = [0, 1, 3, 6].map { radius in focus(radius == 0 ? sharp : blurred(sharp, radius: radius)) ?? -1 }
        #expect(scores[0] > scores[1] && scores[1] > scores[2] && scores[2] > scores[3], "\(scores)")
        #expect(scores[0] - scores[3] > 40, "\(scores)")
    }

    @Test func aBlurredSceneFallsBelowTheBlurLineAndASharpOneDoesNot() {
        let sharp = scene(seed: 6)
        #expect((focus(sharp) ?? 0) > ThumbnailAnalysis.blurLine + 15)
        #expect((focus(blurred(sharp, radius: 4)) ?? 100) < ThumbnailAnalysis.blurLine)
    }

    @Test func brightnessAndContrastDoNotMoveTheScore() {
        let sharp = scene(seed: 7)
        let dimmer = sharp.map { UInt8(Double($0) * 0.5 + 30) }
        let a = focus(sharp) ?? 0, b = focus(dimmer) ?? 0
        #expect(abs(a - b) < 8, "\(a) vs \(b)")
    }

    @Test func turningThePictureSidewaysDoesNotMoveTheScore() {
        let sharp = scene(seed: 8)
        let soft = blurred(sharp, radius: 2)
        #expect(abs((focus(sharp) ?? 0) - (focus(transposed(sharp)) ?? 0)) < 0.01)
        #expect(abs((focus(soft) ?? 0) - (focus(transposed(soft)) ?? 0)) < 0.01)
    }

    @Test func aPictureWithNoStructureIsNotJudged() {
        // A flat wall, a black frame, and a sky that only changes by a third of a gray level per pixel:
        // there is nothing to be in or out of focus. These must not be called blurry.
        #expect(focus([UInt8](repeating: 128, count: side * side)) == nil)
        #expect(focus([UInt8](repeating: 0, count: side * side)) == nil)
        #expect(focus(gradient(from: 100, to: 180)) == nil)
    }

    @Test func aSharpSmoothSceneIsNotMistakenForBlur() {
        // Large flat regions with a few hard edges (a poster, a screenshot of a form): little texture,
        // but the edges that exist are crisp.
        var pixels = [UInt8](repeating: 230, count: side * side)
        for y in 60..<190 { for x in 40..<216 { pixels[y * side + x] = 60 } }
        for y in 100..<150 { for x in 90..<170 { pixels[y * side + x] = 200 } }
        #expect((focus(pixels) ?? 0) > ThumbnailAnalysis.blurLine + 15)
    }

    // MARK: - Exposure

    private func metrics(_ pixels: [UInt8]) -> ThumbnailMetrics { ThumbnailAnalysis.metrics(grayscale: pixels, side: side)! }

    @Test func exposureOfBlackAndWhiteFrames() {
        let black = metrics([UInt8](repeating: 0, count: side * side))
        let white = metrics([UInt8](repeating: 255, count: side * side))
        #expect(black.meanLuminance == 0 && black.highlightLuminance == 0)
        #expect(white.meanLuminance == 1 && white.highlightLuminance == 1)
    }

    @Test func aUniformlyDimFrameIsDimEverywhere() {
        let dim = metrics([UInt8](repeating: 26, count: side * side))   // about 0.10
        #expect(abs(dim.meanLuminance - 0.102) < 0.005)
        #expect(abs(dim.highlightLuminance - 0.102) < 0.005)
    }

    @Test func aNightSceneWithLightsIsDarkOnAverageButNotAtItsHighlights() {
        // Mostly near-black, with 12% of the frame lit: dark by the mean, but plainly not a dead frame.
        var pixels = [UInt8](repeating: 15, count: side * side)
        for y in 0..<side { for x in 0..<(side * 12 / 100) { pixels[y * side + x] = 230 } }
        let m = metrics(pixels)
        #expect(m.meanLuminance < 0.18)
        #expect(m.highlightLuminance > 0.8)
    }

    @Test func aPocketShotIsDarkAtItsHighlightsToo() {
        var rng = PictureRandom(seed: 3)
        let pixels = (0..<(side * side)).map { _ in UInt8(rng.next() % 14) }
        let m = metrics(pixels)
        #expect(m.meanLuminance < 0.06)
        #expect(m.highlightLuminance < 0.3)
    }

    // MARK: - Signature

    @Test func theSignatureMatchesACopyAtAnotherBrightnessAndNotAnotherScene() {
        let a = metrics(scene(seed: 9))
        let brighter = metrics(scene(seed: 9).map { UInt8(min(255, Int($0) + 35)) })
        let other = metrics(scene(seed: 10))
        #expect(a.signature.correlation(with: brighter.signature) > 0.97)
        #expect(a.signature.correlation(with: other.signature) < DuplicateDetectionEngine.minimumCorrelation)
    }

    @Test func aFlatFrameHasAFlatSignature() {
        #expect(metrics([UInt8](repeating: 90, count: side * side)).signature.isFlat)
        #expect(!metrics(scene(seed: 11)).signature.isFlat)
    }

    @Test func aMildCropStillCorrelates() {
        // Cut 2% off each edge and stretch back: a light crop in an editing app. How often heavier crops
        // survive on real photographs is measured by tools/detection_bench, not by this synthetic scene.
        let full = scene(seed: 12)
        let margin = side * 2 / 100, inner = side - 2 * margin
        var cropped = [UInt8](repeating: 0, count: side * side)
        for y in 0..<side { for x in 0..<side {
            let sx = margin + x * inner / side, sy = margin + y * inner / side
            cropped[y * side + x] = full[sy * side + sx]
        } }
        #expect(metrics(full).signature.correlation(with: metrics(cropped).signature) > DuplicateDetectionEngine.minimumCorrelation + 0.03)
    }

    // MARK: - Rules over the measurements

    @Test func blurIsCalledOnlyBelowTheLineAndNeverWithoutAScore() {
        #expect(PhotoRules.isBlurry(focus: ThumbnailAnalysis.blurLine - 0.1))
        #expect(!PhotoRules.isBlurry(focus: ThumbnailAnalysis.blurLine))
        #expect(PhotoRules.isBlurry(focus: 3))
        #expect(!PhotoRules.isBlurry(focus: 60))     // the default "sharp" the app's fixtures use
        #expect(!PhotoRules.isBlurry(focus: nil))    // a picture with no structure is not blurry
    }

    @Test func aDeadFrameIsDarkButANightSceneWithLightsIsNot() {
        #expect(PhotoRules.isDark(luminance: 0.05, highlight: 0.12))
        #expect(PhotoRules.isDark(luminance: 0.17, highlight: 0.29))
        #expect(!PhotoRules.isDark(luminance: 0.17, highlight: 0.38))   // low key, with real highlights
        #expect(!PhotoRules.isDark(luminance: 0.05, highlight: 0.8))    // night scene: a lit sign in a black frame
        #expect(!PhotoRules.isDark(luminance: 0.18, highlight: 0.1))    // not dark on average
        #expect(!PhotoRules.isDark(luminance: nil, highlight: 0.1))
    }

    @Test func withoutHighlightInformationTheMeanAloneDecides() {
        // Items measured before highlights existed, and test fixtures, carry only a mean.
        #expect(PhotoRules.isDark(luminance: 0.1, highlight: nil))
        #expect(!PhotoRules.isDark(luminance: 0.5, highlight: nil))
    }

    @Test func aTallSmallPictureIsADownloadButACameraOriginalIsNot() {
        #expect(PhotoRules.isTallDownload(width: 1_080, height: 1_920))     // a story or reel frame
        #expect(PhotoRules.isTallDownload(width: 1_000, height: 3_000))
        #expect(!PhotoRules.isTallDownload(width: 2_268, height: 4_032))    // a phone's own 16:9 portrait photo
        #expect(!PhotoRules.isTallDownload(width: 2_400, height: 8_000))    // a vertical panorama
        #expect(!PhotoRules.isTallDownload(width: 3_024, height: 4_032))    // an ordinary portrait photo
        #expect(!PhotoRules.isTallDownload(width: 0, height: 0))
    }

    @Test func fewWordsOnManySignsAreNotADocument() {
        #expect(PhotoRules.isDenseText(characters: 500, regions: 8))
        #expect(PhotoRules.isDenseText(characters: 300, regions: 1))        // one dense block
        #expect(PhotoRules.isDenseText(characters: 80, regions: 6))         // a short list or receipt
        #expect(!PhotoRules.isDenseText(characters: 40, regions: 2))
        #expect(!PhotoRules.isDenseText(characters: 35, regions: 9))        // a street of shop signs
        #expect(!PhotoRules.isDenseText(characters: 0, regions: 0))
    }

    // New tests go above this line.
}
