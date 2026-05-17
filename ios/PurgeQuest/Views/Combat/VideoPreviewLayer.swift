//
//  VideoPreviewLayer.swift
//  PurgeQuest
//
//  UIKit-backed view that hosts a single AVPlayerLayer wired to the
//  shared VideoPreviewService player.
//

import SwiftUI
import AVFoundation
import UIKit

struct VideoPreviewLayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.playerLayer.player = VideoPreviewService.shared.sharedPlayer
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = VideoPreviewService.shared.sharedPlayer
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
