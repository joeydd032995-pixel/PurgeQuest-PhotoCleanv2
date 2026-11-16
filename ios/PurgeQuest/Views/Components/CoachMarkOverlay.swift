//
//  CoachMarkOverlay.swift
//  PurgeQuest
//
//  The two arrows on the first card (sub-plan 1.2, task 6): "Swipe left to delete" on the left, "Swipe right to
//  keep" on the right. They are glass chips in the fixed on-glass colors, so they read over any photo, and they
//  let touches through to the card underneath. Static: there is nothing to turn off for Reduce Motion. VoiceOver
//  skips them, since the Delete and Keep buttons and the card's adjustable action already say the same.
//

import SwiftUI

struct CoachMarkOverlay: View {
    var body: some View {
        VStack(spacing: 14) {
            chip(CoachMark.swipeLeftLabel, symbol: "arrow.left", arrowFirst: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            chip(CoachMark.swipeRightLabel, symbol: "arrow.right", arrowFirst: false)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func chip(_ text: String, symbol: String, arrowFirst: Bool) -> some View {
        HStack(spacing: 8) {
            if arrowFirst { Image(systemName: symbol).font(.subheadline.weight(.bold)) }
            Text(text).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            if !arrowFirst { Image(systemName: symbol).font(.subheadline.weight(.bold)) }
        }
        .foregroundStyle(Color.onGlass)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background {
            ZStack {
                BlurEffectView(style: .systemUltraThinMaterialDark)
                Color.glassFill
            }
            .clipShape(Capsule())
        }
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}
