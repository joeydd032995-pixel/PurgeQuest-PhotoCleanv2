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

    var darkFrameRatio: Double { frameCount == 0 ? 0 : Double(darkFrameCount) / Double(frameCount) }

    // Thresholds live here so classifier and tests share one source of truth.
    static let staticMotionThreshold: Double = 0.015
    static let flickerSwingThreshold: Double = 0.45
    static let erraticMotionThreshold: Double = 0.14

    /// Motionless footage — a slideshow posing as a video.
    var isStatic: Bool {
        frameCount >= 2 && meanMotion <= Self.staticMotionThreshold
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

    /// Pure evaluation over per-frame luminances — fully unit-testable.
    static func evaluate(luminances: [Double]) -> VideoFrameSignals? {
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
            darkFrameCount: darkCount
        )
    }
}
