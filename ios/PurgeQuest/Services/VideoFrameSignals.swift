//
//  VideoFrameSignals.swift
//  PurgeQuest
//
//  What a few sampled frames say about a clip. VideoFrameAnalysisService decodes the frames; the
//  arithmetic and the thresholds live here, in Foundation only, so the classifier and its tests share
//  one definition and the Linux harness can run them.
//

import Foundation

/// Aggregated sampled-frame signals for one video.
struct VideoFrameSignals: Sendable, Equatable {
    let frameCount: Int
    /// Mean luminance across sampled frames (0…1).
    let averageLuminance: Double
    /// Mean absolute luminance delta between consecutive sampled frames.
    let meanMotion: Double
    /// Largest absolute luminance delta between consecutive sampled frames.
    let maxLuminanceSwing: Double
    /// Frames at or below the dark-luminance threshold.
    let darkFrameCount: Int
    /// Mean absolute difference between consecutive sampled frames, pixel by pixel on a small
    /// luminance grid (0…1). Unlike `meanMotion`, which only compares each frame's average
    /// brightness, this sees movement that leaves the picture as bright as it was.
    let meanFrameDifference: Double

    var darkFrameRatio: Double { frameCount == 0 ? 0 : Double(darkFrameCount) / Double(frameCount) }

    // Thresholds live here so classifier and tests share one source of truth.
    static let staticMotionThreshold: Double = 0.015
    static let flickerSwingThreshold: Double = 0.45
    static let erraticMotionThreshold: Double = 0.14

    /// Motionless footage — a slideshow posing as a video. The pixels themselves must hold still.
    ///
    /// This used to ask only that the average brightness held (`meanMotion`), and a pan across an
    /// evenly lit room, or someone walking through the frame, keeps the average where it was: such
    /// clips were called motionless and never reached the rules below this one (the Video Vampire,
    /// the Boring Blooper, the three Wraiths). A frame-to-frame difference is never smaller than
    /// the difference of the two averages, so with the same threshold every clip this calls
    /// motionless is one the old rule did too; it only stops calling moving footage still.
    var isStatic: Bool {
        frameCount >= 2 && meanFrameDifference <= Self.staticMotionThreshold
    }
    /// Strobing footage — brightness swings hard between frames while motion persists.
    var isFlickering: Bool {
        frameCount >= 3
            && maxLuminanceSwing >= Self.flickerSwingThreshold
            && meanMotion > Self.staticMotionThreshold
    }
    /// Unsteady handheld motion.
    var isErratic: Bool { meanMotion >= Self.erraticMotionThreshold }
    /// Near-dark across the sampled frames.
    var isDark: Bool {
        frameCount > 0 && averageLuminance <= MonsterClassifier.darkLuminance
    }

    /// Evaluation over whole frames, each a luminance grid (0…1) of the same size. Brightness
    /// signals come from each frame's average, exactly as `evaluate(luminances:)` computes them;
    /// stillness comes from comparing the grids cell by cell. Frames whose size differs from the
    /// first one's, or that hold a value that is not finite, are left out.
    static func evaluate(frames: [[Double]]) -> VideoFrameSignals? {
        guard let size = frames.first?.count, size > 0 else { return nil }
        let usable = frames.filter { $0.count == size && $0.allSatisfy(\.isFinite) }
        guard !usable.isEmpty else { return nil }
        var difference = 0.0
        if usable.count > 1 {
            for i in 1..<usable.count {
                var sum = 0.0
                for cell in 0..<size { sum += abs(usable[i][cell] - usable[i - 1][cell]) }
                difference += sum / Double(size)
            }
            difference /= Double(usable.count - 1)
        }
        let means = usable.map { $0.reduce(0, +) / Double(size) }
        return evaluate(luminances: means, frameDifference: difference)
    }

    /// Pure evaluation over per-frame luminances — fully unit-testable. When only each frame's
    /// average is known, the difference of the averages stands in for the frame difference (its
    /// lower bound); pass `frameDifference` when the frames themselves were compared.
    static func evaluate(luminances: [Double], frameDifference: Double? = nil) -> VideoFrameSignals? {
        let values = luminances.filter { $0.isFinite }
        guard !values.isEmpty else { return nil }

        var deltas: [Double] = []
        deltas.reserveCapacity(max(0, values.count - 1))
        var maxSwing = 0.0
        if values.count > 1 {
            for i in 1..<values.count {
                let d = abs(values[i] - values[i - 1])
                deltas.append(d)
                maxSwing = max(maxSwing, d)
            }
        }
        let meanLuminance = values.reduce(0, +) / Double(values.count)
        let meanDelta = deltas.isEmpty ? 0 : deltas.reduce(0, +) / Double(deltas.count)
        let darkCount = values.filter { $0 <= MonsterClassifier.darkLuminance }.count

        return VideoFrameSignals(
            frameCount: values.count,
            averageLuminance: meanLuminance,
            meanMotion: meanDelta,
            maxLuminanceSwing: maxSwing,
            darkFrameCount: darkCount,
            meanFrameDifference: max(frameDifference ?? meanDelta, meanDelta)
        )
    }
}
