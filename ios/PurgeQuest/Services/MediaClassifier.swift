//
//  MediaClassifier.swift
//  PurgeQuest
//
//  Pluggable media classifier abstraction. The default implementation
//  uses MLAnalysisService heuristics. To integrate a real Core ML model:
//
//    1. Drop `BlurClassifier.mlmodel` (and/or `VideoQualityScorer.mlmodel`)
//       into the project. Xcode auto-generates a Swift class.
//    2. Implement `MediaClassifier` in a new file:
//
//        struct CoreMLPhotoClassifier: PhotoClassifier {
//            private let model: BlurClassifier
//            init() throws { self.model = try BlurClassifier(configuration: .init()) }
//            func classify(asset: PHAsset, thumbnail: UIImage?) -> MonsterType { ... }
//        }
//
//    3. Set `MediaClassifierRegistry.photo = CoreMLPhotoClassifier()`
//       at app launch. Existing fetch pipelines pick it up automatically.
//

import Foundation
import Photos
import UIKit

protocol PhotoClassifier: Sendable {
    func classify(asset: PHAsset, thumbnail: UIImage?) -> MonsterType
}

protocol VideoClassifier: Sendable {
    func classify(asset: PHAsset, estimatedBytes: Int64) -> MonsterType
}

struct HeuristicPhotoClassifier: PhotoClassifier {
    func classify(asset: PHAsset, thumbnail: UIImage?) -> MonsterType {
        MLAnalysisService.classifyPhoto(asset: asset, thumbnail: thumbnail)
    }
}

struct HeuristicVideoClassifier: VideoClassifier {
    func classify(asset: PHAsset, estimatedBytes: Int64) -> MonsterType {
        MLAnalysisService.classifyVideo(asset: asset, estimatedBytes: estimatedBytes)
    }
}

@MainActor
enum MediaClassifierRegistry {
    static var photo: PhotoClassifier = HeuristicPhotoClassifier()
    static var video: VideoClassifier = HeuristicVideoClassifier()
}
