//
//  VideoFrameAnalysisService.swift
//  PurgeQuest
//
//  Rollout stage 3 — deep video analysis. Samples a few small frames across
//  a clip and derives luminance/motion signals that metadata alone cannot
//  see (motionless slideshows, strobing captures, erratic handheld motion,
//  near-dark footage). Only the tiny Sendable signal struct leaves this file
//  (VideoFrameSignals, which also holds the arithmetic and the thresholds);
//  classification lives in MonsterClassifier.
//

import Foundation
import Photos
import AVFoundation
import CoreGraphics

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
        // Each frame is kept as a 16x16 luminance grid, not just its average: whether a clip moves is
        // decided by comparing the grids (VideoFrameSignals.evaluate(frames:)).
        var frames: [[Double]] = []
        for fraction in fractions {
            let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)
            guard let (image, _) = try? await generator.image(at: time),
                  let grid = MLAnalysisService.luminanceGrid(cgImage: image) else { continue }
            frames.append(grid)
        }
        return VideoFrameSignals.evaluate(frames: frames)
    }
}
