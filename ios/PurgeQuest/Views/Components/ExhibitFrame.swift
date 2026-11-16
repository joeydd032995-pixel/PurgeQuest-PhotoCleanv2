//
//  ExhibitFrame.swift
//  PurgeQuest
//
//  The frame a photo hangs in on the combat card (sub-plan 1.2, task 4): a bronze rim, a thin inner mat and
//  the photo, with a glass chip for its size and age in the corner. It replaces the dark text strip that
//  used to cover the lower part of the photo, so the photo is seen whole.
//

import SwiftUI

struct ExhibitFrame<Photo: View>: View {
    /// "12.4 MB · 2 yr ago", shown in a glass chip over the photo's lower corner.
    let chip: String
    let accent: Color
    @ViewBuilder let photo: () -> Photo

    private let outer: CGFloat = 12
    private let rim: CGFloat = 4

    var body: some View {
        photo()
            .clipShape(RoundedRectangle(cornerRadius: outer - rim))
            .overlay(RoundedRectangle(cornerRadius: outer - rim).stroke(Color.black.opacity(0.55), lineWidth: 1))
            .overlay(alignment: .bottomLeading) { chipView }
            .padding(rim)
            .background(
                RoundedRectangle(cornerRadius: outer)
                    .fill(LinearGradient.goldPlate)
                    .overlay(RoundedRectangle(cornerRadius: outer).stroke(accent.opacity(0.5), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: outer).stroke(Color.black.opacity(0.6), lineWidth: 0.5).padding(0.5))
            )
    }

    /// A blur of the photo under a dark tint, in the fixed on-glass colors, so it reads over any photo.
    private var chipView: some View {
        Text(chip)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.onGlass)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background {
                ZStack {
                    BlurEffectView(style: .systemUltraThinMaterialDark)
                    Color.glassFill
                }
                .clipShape(Capsule())
            }
            .padding(8)
            .accessibilityHidden(true)
    }
}
