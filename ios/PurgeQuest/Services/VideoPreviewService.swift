//
//  VideoPreviewService.swift
//  PurgeQuest
//
//  Lightweight, single-instance AVPlayer pool for combat card video
//  previews. Only the front-most card receives a player; everyone else
//  uses the static thumbnail. Players are returned to the pool when a
//  card disappears, keeping memory and decoder pressure low.
//

import Foundation
import AVFoundation
import Photos

@MainActor
final class VideoPreviewService {
    static let shared = VideoPreviewService()

    /// Reusable AVPlayer (we only ever play one preview at a time).
    private let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    private var currentAssetID: String?
    private var loadingTask: Task<Void, Never>?

    private init() {
        let p = AVQueuePlayer()
        p.isMuted = true
        p.actionAtItemEnd = .advance
        p.automaticallyWaitsToMinimizeStalling = false
        self.player = p
    }

    var sharedPlayer: AVQueuePlayer { player }

    /// Loads the asset for `phAssetID` and starts looping playback.
    /// If we are already showing this asset, this is a no-op.
    func play(phAssetID: String) {
        if currentAssetID == phAssetID, player.timeControlStatus == .playing { return }
        loadingTask?.cancel()
        currentAssetID = phAssetID

        loadingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [phAssetID], options: nil)
            guard let asset = fetch.firstObject else { return }
            guard asset.mediaType == .video else { return }

            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .fastFormat
            options.version = .current

            let item: AVPlayerItem? = await withCheckedContinuation { cont in
                PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                    cont.resume(returning: item)
                }
            }
            guard !Task.isCancelled, let item, self.currentAssetID == phAssetID else { return }

            self.player.removeAllItems()
            self.looper = AVPlayerLooper(player: self.player, templateItem: item)
            await self.player.seek(to: .zero)
            self.player.play()
        }
    }

    /// Pause and clear any in-flight load. Safe to call repeatedly.
    func stop(forAssetID id: String? = nil) {
        if let id, currentAssetID != id { return }
        loadingTask?.cancel()
        loadingTask = nil
        player.pause()
        player.removeAllItems()
        looper = nil
        currentAssetID = nil
    }
}
