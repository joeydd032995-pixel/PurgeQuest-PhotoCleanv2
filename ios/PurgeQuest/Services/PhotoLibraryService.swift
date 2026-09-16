//
//  PhotoLibraryService.swift
//  PurgeQuest
//

import Foundation
import Photos
import UIKit
import CryptoKit

enum PhotoLibraryError: Error, LocalizedError {
    case denied
    case limited
    case fetchFailed
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .denied: return "PurgeQuest needs Photo Library access to find monsters in your camera roll."
        case .limited: return "Limited Photo Library access. Only the photos you allowed will appear."
        case .fetchFailed: return "Could not load media from your library."
        case .deletionFailed(let m): return "Couldn't move items to Recently Deleted: \(m)"
        }
    }
}

struct LibraryStats: Sendable {
    var totalItems: Int = 0
    var photoCount: Int = 0
    var videoCount: Int = 0
    var estimatedBytes: Int64 = 0

    var estimatedGB: Double { Double(estimatedBytes) / 1_073_741_824.0 }
}

@MainActor
final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    let cachingManager = PHCachingImageManager()

    private init() {}

    // MARK: - Authorization

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                cont.resume(returning: status)
            }
        }
    }

    // MARK: - Stats

    func fetchLibraryStats() -> LibraryStats {
        let opts = PHFetchOptions()
        opts.includeHiddenAssets = false
        let all = PHAsset.fetchAssets(with: opts)
        var stats = LibraryStats()
        all.enumerateObjects { asset, _, _ in
            stats.totalItems += 1
            switch asset.mediaType {
            case .image: stats.photoCount += 1
            case .video: stats.videoCount += 1
            default: break
            }
            // Cheap estimate using pixel area * heuristic; resource-based size requires async I/O.
            let estimate = Int64(asset.pixelWidth * asset.pixelHeight) / 6
            let videoMultiplier = asset.mediaType == .video ? Int64(max(1, asset.duration)) * 600_000 : 0
            stats.estimatedBytes += estimate + videoMultiplier
        }
        return stats
    }

    // MARK: - Fetching

    /// Fetch oldest-first up to `limit` assets, optionally filtered to videos only.
    func fetchAssets(limit: Int, includeVideos: Bool = true, videoOnly: Bool = false) -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        opts.fetchLimit = limit
        opts.includeHiddenAssets = false

        let result: PHFetchResult<PHAsset>
        if videoOnly {
            result = PHAsset.fetchAssets(with: .video, options: opts)
        } else if !includeVideos {
            result = PHAsset.fetchAssets(with: .image, options: opts)
        } else {
            // Mixed: no media-type filter — both images and videos.
            result = PHAsset.fetchAssets(with: opts)
        }

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // MARK: - Thumbnails

    func requestThumbnail(for asset: PHAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { cont in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            var resumed = false
            cachingManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: image)
            }
        }
    }

    // MARK: - Resource size

    func estimateBytes(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for r in resources {
            if let size = r.value(forKey: "fileSize") as? Int64, size > 0 {
                return size
            }
            if let size = r.value(forKey: "fileSize") as? NSNumber {
                return size.int64Value
            }
        }
        // Fallback heuristic
        if asset.mediaType == .video {
            return Int64(max(1, asset.duration)) * 4_000_000 // ~4MB/s rough avg
        }
        return Int64(asset.pixelWidth * asset.pixelHeight) / 6
    }

    // MARK: - Build MediaItems

    /// Builds MediaItems with the cheap explainability signals captured at
    /// fetch time. A provisional solo classification is attached; the batch
    /// classifier (MonsterClassifier) refines duplicate groups afterwards.
    func buildMediaItems(from assets: [PHAsset], thumbSize: CGSize, withThumbnails: Bool = true) async -> [MediaItem] {
        var items: [MediaItem] = []
        items.reserveCapacity(assets.count)
        for asset in assets {
            let bytes = estimateBytes(for: asset)
            let thumb = withThumbnails ? await requestThumbnail(for: asset, size: thumbSize) : nil
            let signals = captureSignals(for: asset)
            var item = MediaItem(
                id: asset.localIdentifier,
                kind: asset.mediaType == .video ? .video : .photo,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                durationSeconds: asset.duration,
                estimatedBytes: bytes,
                isFavorite: asset.isFavorite,
                playbackStyle: asset.playbackStyle.rawValue,
                isScreenshot: signals.isScreenshot,
                hasEdits: signals.hasEdits,
                isScreenRecording: signals.isScreenRecording,
                isLivePhoto: signals.isLivePhoto,
                isLooping: signals.isLooping,
                isHighFrameRate: signals.isHighFrameRate,
                sharpness: thumb.map { MLAnalysisService.sharpnessVariance(image: $0) },
                luminance: thumb.map { MLAnalysisService.averageLuminance(image: $0) },
                thumbnail: thumb
            )
            let solo = MonsterClassifier.classifySolo(item)
            item.monsterType = solo.monsterType
            item.classification = solo
            items.append(item)
        }
        return items
    }

    /// Metadata-only composition snapshot (no thumbnails) for theme scouting.
    func fetchLibraryComposition(limit: Int = 400) -> LibraryComposition {
        let assets = fetchAssets(limit: limit, includeVideos: true)
        var items: [MediaItem] = []
        items.reserveCapacity(assets.count)
        for asset in assets {
            let signals = captureSignals(for: asset)
            items.append(MediaItem(
                id: asset.localIdentifier,
                kind: asset.mediaType == .video ? .video : .photo,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                durationSeconds: asset.duration,
                estimatedBytes: estimateBytes(for: asset),
                isFavorite: asset.isFavorite,
                playbackStyle: asset.playbackStyle.rawValue,
                isScreenshot: signals.isScreenshot,
                hasEdits: signals.hasEdits,
                isScreenRecording: signals.isScreenRecording,
                isLivePhoto: signals.isLivePhoto,
                isLooping: signals.isLooping,
                isHighFrameRate: signals.isHighFrameRate
            ))
        }
        return DungeonThemeEngine.composition(for: items)
    }

    /// Cheap, explainable signals read straight from PHAsset metadata.
    private func captureSignals(for asset: PHAsset) -> (isScreenshot: Bool, hasEdits: Bool, isScreenRecording: Bool, isLivePhoto: Bool, isLooping: Bool, isHighFrameRate: Bool) {
        let resources = PHAssetResource.assetResources(for: asset)
        return (
            asset.mediaSubtypes.contains(.photoScreenshot),
            resources.contains { $0.type == .fullSizePhoto || $0.type == .fullSizeVideo || $0.type == .adjustmentData },
            resources.contains { $0.originalFilename.localizedCaseInsensitiveContains("screen recording") },
            asset.playbackStyle == .livePhoto,
            asset.playbackStyle == .videoLooping,
            asset.mediaSubtypes.contains(.videoHighFrameRate)
        )
    }

    /// Partial SHA-256 of the primary resource's first 256 KB — a cheap exact-
    /// duplicate fingerprint. Only called for metadata-equal candidate pairs,
    /// keeping IO bounded. Nil when the bytes can't be read locally.
    func contentHash(for asset: PHAsset) async -> String? {
        let resources = PHAssetResource.assetResources(for: asset)
        let primary = resources.first { $0.type == .photo }
            ?? resources.first { $0.type == .video }
            ?? resources.first
        guard let primary else { return nil }
        return await withCheckedContinuation { cont in
            var hasher = SHA256()
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            var bytesHashed = 0
            var resumed = false
            PHAssetResourceManager.default().requestData(
                for: primary,
                options: options,
                dataReceivedHandler: { data in
                    // Cap at the first 256 KB to keep IO cheap.
                    guard bytesHashed < 262_144 else { return }
                    let prefix = data.prefix(262_144 - bytesHashed)
                    hasher.update(data: prefix)
                    bytesHashed += prefix.count
                },
                completionHandler: { error in
                    guard !resumed else { return }
                    resumed = true
                    guard error == nil, bytesHashed > 0 else { cont.resume(returning: nil); return }
                    let digest = hasher.finalize()
                    cont.resume(returning: digest.map { String(format: "%02x", $0) }.joined())
                }
            )
        }
    }

    // MARK: - Deletion

    /// Move the given assets to "Recently Deleted". Throws on failure.
    func deleteAssets(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { throw PhotoLibraryError.deletionFailed("No matching assets") }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            } completionHandler: { success, error in
                if success {
                    cont.resume()
                } else if let error {
                    cont.resume(throwing: PhotoLibraryError.deletionFailed(error.localizedDescription))
                } else {
                    cont.resume(throwing: PhotoLibraryError.deletionFailed("User cancelled"))
                }
            }
        }
    }
}
