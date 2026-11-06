//
//  LivePhotoPreviewView.swift
//  PurgeQuest
//
//  Live Photo playback for combat cards: fetches the paired photo+video for
//  a PHAsset and plays it through UIKit's PHLivePhotoView with the full
//  back-and-forth loop. Falls back to a clean error state when the asset
//  has no live-photo pair.
//

import SwiftUI
import Photos
import PhotosUI

struct LivePhotoPreviewView: View {
    let phAssetID: String

    @State private var livePhoto: PHLivePhoto? = nil
    @State private var failed = false

    var body: some View {
        ZStack {
            if let livePhoto {
                LivePhotoPlayerView(livePhoto: livePhoto)
            } else if failed {
                ZStack {
                    Color.black.opacity(0.55)
                    VStack(spacing: 6) {
                        Image(systemName: "livephoto.slash")
                            .font(.title2)
                        Text("Live Photo unavailable")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityLabel("Live Photo playback unavailable")
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: phAssetID) { await load() }
        .onDisappear { livePhoto = nil }
    }

    private func load() async {
        failed = false
        livePhoto = nil
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [phAssetID], options: nil
        ).firstObject else {
            failed = true
            return
        }
        let photo: PHLivePhoto? = await withCheckedContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { result, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                guard !degraded else { return }
                continuation.resume(returning: result)
            }
        }
        if let photo {
            livePhoto = photo
        } else {
            failed = true
        }
    }
}

/// PHLivePhotoView wrapper; plays the paired motion once per mount.
private struct LivePhotoPlayerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.livePhoto = livePhoto
        view.startPlayback(with: .full)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        if uiView.livePhoto !== livePhoto {
            uiView.livePhoto = livePhoto
            uiView.startPlayback(with: .full)
        }
    }
}
