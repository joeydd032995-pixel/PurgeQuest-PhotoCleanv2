//
//  VideoDressing.swift
//  PurgeQuest
//
//  What a video card does while its looping preview plays (design section 6): a soft vignette in the outer 8% of the
//  picture, never darker than 9%, and a slow breath, the preview growing 1.5% and settling again over four seconds.
//  No letterbox bars: they would cover picture. The breath is a loop, so it is off under Reduce Motion or Low Power
//  Mode; the vignette stays.
//

import SwiftUI

struct VideoPreviewStage: View {
    let gate: FXGate

    @State private var inhale = false

    var body: some View {
        let breathing: Bool = !gate.isStill
        let scale: CGFloat = (breathing && inhale) ? 1.015 : 1.0
        VideoPreviewLayerView()
            .scaleEffect(scale)
            .overlay { VideoVignette() }
            .onAppear {
                guard breathing else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { inhale = true }
            }
            .onChange(of: gate.isStill) { _, isStill in
                // Low Power Mode came on while it was breathing: settle and stop.
                if isStill { withAnimation(.easeOut(duration: 0.2)) { inhale = false } }
            }
    }
}

/// Four soft edges at most 9% black, none overlapping, so the darkest point is 9%.
struct VideoVignette: View {
    var body: some View {
        GeometryReader { proxy in
            let band: CGFloat = min(proxy.size.width, proxy.size.height) * 0.08
            let sideHeight: CGFloat = max(0, proxy.size.height - 2 * band)
            let fade: [Color] = [Color.black.opacity(0.09), Color.clear]
            ZStack {
                LinearGradient(colors: fade, startPoint: .top, endPoint: .bottom)
                    .frame(height: band)
                    .frame(maxHeight: .infinity, alignment: .top)
                LinearGradient(colors: fade, startPoint: .bottom, endPoint: .top)
                    .frame(height: band)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                LinearGradient(colors: fade, startPoint: .leading, endPoint: .trailing)
                    .frame(width: band, height: sideHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                LinearGradient(colors: fade, startPoint: .trailing, endPoint: .leading)
                    .frame(width: band, height: sideHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
