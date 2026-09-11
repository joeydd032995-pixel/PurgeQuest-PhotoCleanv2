//
//  MiniAvatar+Identity.swift
//  PurgeQuest
//
//  The hero's own identity layer: bare head, face features (eyes, brows,
//  mouth, blush), and hair. Everything is drawn through the shared cel
//  system so the face reads as part of the same figure as the gear that
//  equips over it. Cosmetic heads in MiniAvatar+Heads.swift reuse these
//  parts so identity stays present under helmets, hats, and hoods.
//

import SwiftUI

extension MiniAvatarView {

    // MARK: - Bare head

    /// No-headgear head: skin dome in the chosen face shape, identity face,
    /// and hair. Long hair also renders a back panel behind the dome.
    var identityHead: some View {
        ZStack {
            hairBack
            identityHeadBase
            identityFace(browY: 2, eyeY: 7, mouthY: 15, blushY: 10)
            hairFront
            neckRing
        }
    }

    /// Head dome silhouette for the current face shape.
    @ViewBuilder var identityHeadBase: some View {
        switch identity.faceShape {
        case .round:
            cel(Circle(), skinTone, lineWidth: 2.6, shift: 2.0)
                .frame(width: 60 * u, height: 55 * u)
        case .boulder:
            cel(RoundedRectangle(cornerRadius: 14 * u, style: .continuous), skinTone, lineWidth: 2.6, shift: 2.0)
                .frame(width: 58 * u, height: 54 * u)
        case .nimble:
            cel(Ellipse(), skinTone, lineWidth: 2.6, shift: 2.0)
                .frame(width: 54 * u, height: 57 * u)
        }
    }

    // MARK: - Face

    /// Full identity face: brows, eyes, blush, and mouth. The y offsets are
    /// in head-local design units so bare heads, helmet windows, and the
    /// wizard face can each lay the features out for their frame.
    func identityFace(
        browY: CGFloat,
        eyeY: CGFloat,
        mouthY: CGFloat,
        blushY: CGFloat,
        showsMouth: Bool = true
    ) -> some View {
        ZStack {
            brow(side: -1)
                .offset(y: (browY + expressionBrowLift) * u)
            brow(side: 1)
                .offset(y: (browY + expressionBrowLift) * u)
            HStack(spacing: 7 * u) {
                identityEye
                identityEye
            }
            .offset(y: eyeY * u)
            HStack(spacing: 14 * u) {
                blush
                blush
            }
            .offset(y: blushY * u)
            if showsMouth {
                mouth
                    .offset(y: mouthY * u)
            }
        }
    }

    /// One chunky eye in the chosen style and iris color.
    @ViewBuilder var identityEye: some View {
        switch identity.eyeStyle {
        case .bright:
            let shape = RoundedRectangle(cornerRadius: 3 * u, style: .continuous)
            ZStack {
                shape.fill(outline)
                    .frame(width: 7 * u, height: 10 * u)
                Circle().fill(identity.eyeColor.color)
                    .frame(width: 5 * u, height: 5 * u)
                    .offset(y: 1.4 * u)
                Circle().fill(outline)
                    .frame(width: 2.4 * u, height: 2.4 * u)
                    .offset(x: 0.4 * u, y: 1.7 * u)
                Circle().fill(Color.white)
                    .frame(width: 2.2 * u, height: 2.2 * u)
                    .offset(x: -1.1 * u, y: -2.4 * u)
            }
        case .keen:
            let shape = RoundedRectangle(cornerRadius: 2.2 * u, style: .continuous)
            ZStack {
                shape.fill(outline)
                    .frame(width: 6.6 * u, height: 8.6 * u)
                Circle().fill(identity.eyeColor.color)
                    .frame(width: 4.4 * u, height: 4.4 * u)
                    .offset(y: 1.2 * u)
                Circle().fill(outline)
                    .frame(width: 2.2 * u, height: 2.2 * u)
                    .offset(x: 0.4 * u, y: 1.4 * u)
                Rectangle().fill(skinTone)
                    .frame(width: 8 * u, height: 4.4 * u)
                    .rotationEffect(.degrees(14))
                    .offset(y: -3.4 * u)
                Circle().fill(Color.white)
                    .frame(width: 1.8 * u, height: 1.8 * u)
                    .offset(x: -1 * u, y: -1.4 * u)
            }
            .clipShape(shape)
        case .gentle:
            let shape = Ellipse()
            ZStack {
                shape.fill(outline)
                    .frame(width: 7.2 * u, height: 8.4 * u)
                Circle().fill(identity.eyeColor.color)
                    .frame(width: 4.6 * u, height: 4.6 * u)
                    .offset(y: 1 * u)
                Circle().fill(outline)
                    .frame(width: 2.2 * u, height: 2.2 * u)
                    .offset(x: 0.4 * u, y: 1.2 * u)
                Rectangle().fill(skinTone)
                    .frame(width: 8.2 * u, height: 3.4 * u)
                    .offset(y: -3.2 * u)
                Circle().fill(Color.white)
                    .frame(width: 1.8 * u, height: 1.8 * u)
                    .offset(x: -1 * u, y: -1.6 * u)
            }
            .clipShape(shape)
        }
    }

    /// One brow, mirrored per side. Angles come from the brow style nudged
    /// by the overall expression.
    func brow(side: CGFloat) -> some View {
        let thickness: CGFloat = identity.browStyle == .stern ? 2.4 : 1.9
        return Capsule()
            .fill(hairColor.darker(0.30))
            .frame(width: 8 * u, height: thickness * u)
            .rotationEffect(.degrees(-side * totalBrowAngle))
            .offset(x: side * 7.5 * u)
    }

    /// Combined brow angle: style base plus the expression mood.
    var totalBrowAngle: CGFloat {
        let base: CGFloat
        switch identity.browStyle {
        case .steady: base = 4
        case .fierce: base = 13
        case .worried: base = -12
        case .stern: base = 0
        }
        let mood: CGFloat
        switch identity.expression {
        case .calm: mood = 0
        case .fierce: mood = 6
        case .happy: mood = -5
        case .weary: mood = 3
        }
        return base + mood
    }

    var expressionBrowLift: CGFloat {
        switch identity.expression {
        case .calm: return 0
        case .fierce: return -1
        case .happy: return -2
        case .weary: return 2
        }
    }

    var blush: some View {
        Circle()
            .fill(skinShade.opacity(blushOpacity))
            .frame(width: 4.5 * u, height: 3 * u)
    }

    var blushOpacity: Double {
        switch identity.expression {
        case .calm: return 0.40
        case .fierce: return 0.25
        case .happy: return 0.55
        case .weary: return 0.22
        }
    }

    @ViewBuilder var mouth: some View {
        switch identity.mouthStyle {
        case .smile:
            SmileShape()
                .stroke(outline, style: StrokeStyle(lineWidth: 1.7 * u, lineCap: .round))
                .frame(width: 8 * u, height: 3.4 * u)
        case .grin:
            let shape = RoundedRectangle(cornerRadius: 2.4 * u, style: .continuous)
            ZStack {
                shape.fill(outline)
                Rectangle().fill(Color(white: 0.94))
                    .frame(width: 7.5 * u, height: 2 * u)
                    .offset(y: -1.4 * u)
            }
            .frame(width: 9.5 * u, height: 5.5 * u)
            .clipShape(shape)
            .overlay(shape.stroke(outline, lineWidth: max(1.2 * u, 1.1)))
        case .neutral:
            Capsule()
                .fill(outline)
                .frame(width: 6 * u, height: 1.7 * u)
        case .frown:
            SmileShape(flip: true)
                .stroke(outline, style: StrokeStyle(lineWidth: 1.7 * u, lineCap: .round))
                .frame(width: 7 * u, height: 3 * u)
        }
    }

    // MARK: - Hair

    /// Back panel behind the head for the long style.
    @ViewBuilder var hairBack: some View {
        if identity.hairStyle == .long {
            cel(RoundedRectangle(cornerRadius: 14 * u, style: .continuous), hairColor, lineWidth: 2.4, shift: 1.8)
                .frame(width: 46 * u, height: 60 * u)
                .offset(y: 8 * u)
        }
    }

    /// Front hair on the bare head, per style.
    @ViewBuilder var hairFront: some View {
        switch identity.hairStyle {
        case .bald:
            EmptyView()
        case .buzz:
            cel(HairCapShape(), hairColor, lineWidth: 1.8, shift: 1.0)
                .frame(width: 56 * u, height: 22 * u)
                .offset(y: -15 * u)
        case .short:
            cel(HairCapShape(), hairColor, lineWidth: 2.2, shift: 1.3)
                .frame(width: 58 * u, height: 30 * u)
                .offset(y: -13 * u)
        case .swept:
            cel(HairSweptShape(), hairColor, lineWidth: 2.2, shift: 1.3)
                .frame(width: 60 * u, height: 34 * u)
                .offset(y: -12 * u)
        case .long:
            cel(HairCapShape(), hairColor, lineWidth: 2.2, shift: 1.3)
                .frame(width: 58 * u, height: 28 * u)
                .offset(y: -14 * u)
        }
    }

    /// Bangs peeking out under a helmet's brow band, so identity stays
    /// present under gear.
    @ViewBuilder var helmBangs: some View {
        if identity.hairStyle != .bald {
            cel(HairCapShape(), hairColor, lineWidth: 1.6, shift: 0.9)
                .frame(width: 38 * u, height: 11 * u)
                .offset(y: -9 * u)
        }
    }

    /// Bangs peeking out under a wizard hat brim.
    @ViewBuilder var wizardBangs: some View {
        if identity.hairStyle != .bald {
            cel(HairCapShape(fringeDepth: 0.5), hairColor, lineWidth: 1.6, shift: 0.9)
                .frame(width: 38 * u, height: 10 * u)
                .offset(y: -14 * u)
        }
    }
}
