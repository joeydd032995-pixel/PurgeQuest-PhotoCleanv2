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
    /// "12.4 MB · 2 yr ago", shown in a glass chip over the photo's lower corner; nil for none.
    let chip: String?
    let accent: Color
    /// 0...1: how far the photo has lifted off the frame, from the drag. 0 at rest.
    var lift: Double = 0
    /// Degrees the frame's lit edge swings with the card's tilt. 0 at rest.
    var highlightShift: Double = 0
    @ViewBuilder let photo: () -> Photo

    private let outer: CGFloat = 12
    private let rim: CGFloat = 4

    var body: some View {
        let photoShadow = LightSource.shadowOffset(depth: 3 + 7 * lift)
        photo()
            .clipShape(RoundedRectangle(cornerRadius: outer - rim))
            .overlay(RoundedRectangle(cornerRadius: outer - rim).stroke(Color.black.opacity(0.55), lineWidth: 1))
            .overlay(alignment: .bottomLeading) { chipView }
            .scaleEffect(1 + 0.03 * lift)
            .shadow(color: .black.opacity(0.30 * lift), radius: 3 + 9 * lift, x: photoShadow.x, y: photoShadow.y)
            .padding(rim)
            .background(frameBackground)
    }

    /// The bronze rim: the plate gradient, the accent and dark keylines, a faint lit edge that moves with the tilt,
    /// and a shadow that deepens as the photo lifts. Light and shadow both come from `LightSource`.
    private var frameBackground: some View {
        let frameShadow = LightSource.shadowOffset(depth: 2 + 4 * lift)
        let points = LightSource.highlightPoints(shiftDegrees: highlightShift)
        return RoundedRectangle(cornerRadius: outer)
            .fill(LinearGradient.goldPlate)
            .overlay(RoundedRectangle(cornerRadius: outer).stroke(accent.opacity(0.5), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: outer).stroke(Color.black.opacity(0.6), lineWidth: 0.5).padding(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: outer - 1)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0), Color.black.opacity(0.25)],
                            startPoint: UnitPoint(x: points.start.x, y: points.start.y),
                            endPoint: UnitPoint(x: points.end.x, y: points.end.y)
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            )
            .shadow(color: .black.opacity(0.25 + 0.15 * lift), radius: 5 + 8 * lift, x: frameShadow.x, y: frameShadow.y)
    }

    /// A blur of the photo under a dark tint, in the fixed on-glass colors, so it reads over any photo.
    @ViewBuilder
    private var chipView: some View {
        if let chip {
            chipText(chip)
        }
    }

    private func chipText(_ chip: String) -> some View {
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
