//
//  BlurEffectView.swift
//  PurgeQuest
//
//  UIKit's UIVisualEffectView wrapped for SwiftUI — the real system blur,
//  used to frost media overlays so text stays readable over any photo or
//  video frame.
//

import SwiftUI
import UIKit

struct BlurEffectView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterialDark

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        let effect = UIBlurEffect(style: style)
        // Reassigning an identical effect is a no-op for UIKit; only swap when
        // the style actually changed to avoid mid-gesture blinks.
        if (uiView.effect as? UIBlurEffect) != effect {
            uiView.effect = effect
        }
    }
}
