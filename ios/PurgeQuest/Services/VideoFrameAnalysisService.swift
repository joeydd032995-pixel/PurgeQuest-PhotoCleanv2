//
//  VideoFrameAnalysisService.swift
//  PurgeQuest
//
//  Rollout stage 3 — deep video analysis. Samples a few small frames across
//  a clip and derives luminance/motion signals that metadata alone cannot
//  see (motionless slideshows, strobing captures, erratic handheld motion,
//  near-dark footage). Only the tiny Sendable signal struct leaves this file;
//  classification lives in MonsterClassifier.
//

import Foundation
import Photos
import AVFoundation
import CoreGraphics

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

enum VideoFrameAnalysisService {

    /// Sampled frames per clip. Three tiny reads keep IO bounded while still
    /// separating static, strobing, and erratic footage.
    static let sampleCount = 3
    static let maximumSampleSize = CGSize(width: 128, height: 128)

    /// Samples up to three small frames across the clip and evaluates the
    /// signals. Nil when the clip can't be read (the caller treats render
    /// failures as a Glitchborn signal instead).
    static func signals(for asset: PHAsset) async -> VideoFrameSignals? {
        guard asset.mediaType == .video, asset.duration > 0 else { return nil }

        let item: AVPlayerItem? = await withCheckedContinuation { cont in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            var resumed = false
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: playerItem)
            }
        }
        guard let item else { return nil }

        guard let seconds = try? await item.asset.load(.duration).seconds, seconds.isFinite, seconds > 0 else {
            return nil
        }

        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSampleSize
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

        // Sample deep enough to miss intros, centered enough to catch content.
        let fractions = [0.1, 0.5, 0.9].prefix(max(2, min(sampleCount, 3)))
        var luminances: [Double] = []
        for fraction in fractions {
            let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)
            guard let (image, _) = try? await generator.image(at: time) else { continue }
            luminances.append(MLAnalysisService.averageLuminance(cgImage: image))
        }
        return VideoFrameSignals.evaluate(luminances: luminances)
    }
}
