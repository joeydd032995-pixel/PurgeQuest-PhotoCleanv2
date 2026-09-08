//
//  MiniAvatar+Heads.swift
//  PurgeQuest
//
//  Head models for the chunky hero figure: the knight dome, cosmetic helms,
//  wizard hats, and the shadow hood. All faces share the same eye style so
//  the cast reads as one family.
//

import SwiftUI

extension MiniAvatarView {

    var headGroup: some View {
        headModel
            .offset(y: -30 * u)
    }

    @ViewBuilder var headModel: some View {
        switch item(.head)?.id {
        case "head.iron": ironHelmet
        case "head.dragoncrest": dragonHelmet
        case "head.starhat": starWizardHead
        case "head.hood": hoodedHead
        default:
            if isKnight { knightHead } else { wizardHead }
        }
    }

    // MARK: - Shared pieces

    /// Chunky eye: dark oval with one big catchlight.
    var heroEye: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5 * u, style: .continuous)
                .fill(outline)
                .frame(width: 7.5 * u, height: 10.5 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 3.2 * u, height: 3.2 * u)
                .offset(x: -1.1 * u, y: -2.6 * u)
        }
    }

    /// Neck ring seating the head onto the torso.
    var neckRing: some View {
        celFlat(Capsule(), steelDeep, lineWidth: 1.6)
            .frame(width: 17 * u, height: 5 * u)
            .offset(y: 27 * u)
    }

    /// Twin gold crest lobes rooted in the dome, splaying outward.
    var knightCrest: some View {
        ZStack {
            cel(CrestLobeShape(), .questAmber, lineWidth: 2.0, shift: 1.2)
                .frame(width: 12 * u, height: 26 * u)
                .rotationEffect(.degrees(-16))
                .offset(x: -7.5 * u, y: -26 * u)
            cel(CrestLobeShape(), .questAmber, lineWidth: 2.0, shift: 1.2)
                .frame(width: 12 * u, height: 26 * u)
                .rotationEffect(.degrees(16))
                .offset(x: 7.5 * u, y: -26 * u)
        }
    }

    // MARK: - Knight heads

    /// Default knight: full steel enclosure — dome, brow band, visor slot,
    /// chin plate — with the crest rooted in the dome itself.
    var knightHead: some View {
        ZStack {
            knightCrest
            cel(Circle(), steel, lineWidth: 2.6, shift: 2.0)
                .frame(width: 62 * u, height: 57 * u)
            // Brow band shading the visor opening.
            celFlat(Capsule(), steelDeep, lineWidth: 1.4)
                .frame(width: 40 * u, height: 5 * u)
                .offset(y: -9 * u)
            ZStack {
                celFlat(FaceWindowShape(), helmetDark, lineWidth: 2.2)
                    .frame(width: 42 * u, height: 26 * u)
                face
            }
            .offset(y: 3 * u)
            // Chin plate closing the helmet below the visor.
            cel(Capsule(), steel, lineWidth: 2.2, shift: 1.2)
                .frame(width: 46 * u, height: 13 * u)
                .offset(y: 20 * u)
            // Cheek rivets flanking the visor.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                celFlat(Circle(), .questAmber, lineWidth: 1.2)
                    .frame(width: 3.4 * u, height: 3.4 * u)
                    .offset(x: side * 18 * u, y: 7 * u)
            }
            neckRing
        }
    }

    /// Skin plate inside the visor: hard brim shadow, eyes, blush.
    var face: some View {
        ZStack {
            ZStack(alignment: .top) {
                FaceWindowShape().fill(skinTone)
                Rectangle().fill(skinShade.opacity(0.5)).frame(height: 4.5 * u)
            }
            .frame(width: 38 * u, height: 22 * u)
            .clipShape(FaceWindowShape())
            .overlay(FaceWindowShape().stroke(outline, lineWidth: 1.4 * u))
            HStack(spacing: 7 * u) {
                heroEye
                heroEye
            }
            .offset(y: -0.5 * u)
            HStack(spacing: 14 * u) {
                Circle().fill(skinShade.opacity(0.45)).frame(width: 4.5 * u, height: 3 * u)
                Circle().fill(skinShade.opacity(0.45)).frame(width: 4.5 * u, height: 3 * u)
            }
            .offset(y: 6 * u)
        }
    }

    /// Iron Helm: full steel dome, brow arc, dark slit, riveted gold band.
    var ironHelmet: some View {
        ZStack {
            cel(Circle(), steel, lineWidth: 2.6, shift: 2.0)
                .frame(width: 58 * u, height: 53 * u)
            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(steelLight, style: StrokeStyle(lineWidth: 2.5 * u, lineCap: .round))
                .frame(width: 46 * u, height: 41 * u)
                .offset(y: -6 * u)
            celFlat(Capsule(), outline, lineWidth: 1.4)
                .frame(width: 34 * u, height: 6.5 * u)
                .offset(y: -6 * u)
            celFlat(Capsule(), .questAmber, lineWidth: 1.8)
                .frame(width: 44 * u, height: 4.5 * u)
                .offset(y: 8 * u)
            ForEach([CGFloat(-1), CGFloat(0), CGFloat(1)], id: \.self) { x in
                Circle()
                    .fill(outline.opacity(0.55))
                    .frame(width: 1.8 * u, height: 1.8 * u)
                    .offset(x: x * 13 * u, y: 8 * u)
            }
            neckRing
        }
    }

    /// Dragoncrest Helm: gold dome, crimson fin crest, scale etching.
    var dragonHelmet: some View {
        ZStack {
            cel(FinShape(), .combatCrimson, lineWidth: 2.2, shift: 1.4)
                .frame(width: 20 * u, height: 18 * u)
                .offset(x: -1 * u, y: -27 * u)
            cel(Circle(), .questAmber, lineWidth: 2.6, shift: 2.0)
                .frame(width: 58 * u, height: 53 * u)
            celFlat(Capsule(), outline, lineWidth: 1.4)
                .frame(width: 34 * u, height: 6.5 * u)
                .offset(y: -6 * u)
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                celFlat(ScaleShape(), Color.questAmber.darker(0.22), lineWidth: 1.2)
                    .frame(width: 8 * u, height: 5 * u)
                    .offset(x: side * 13 * u, y: 4 * u)
            }
            celFlat(Capsule(), Color(red: 0.62, green: 0.46, blue: 0.18), lineWidth: 1.6)
                .frame(width: 17 * u, height: 5 * u)
                .offset(y: 27 * u)
        }
    }

    // MARK: - Wizard heads

    var wizardHead: some View {
        ZStack {
            wizardFaceGroup
            wizardHat(starred: false)
            neckRing
        }
    }

    var starWizardHead: some View {
        ZStack {
            wizardFaceGroup
            wizardHat(starred: true)
            neckRing
        }
    }

    /// Round face, white beard, chunky mustache.
    var wizardFaceGroup: some View {
        ZStack {
            ZStack(alignment: .top) {
                Circle().fill(skinTone)
                Rectangle().fill(skinShade.opacity(0.45)).frame(height: 6 * u)
            }
            .frame(width: 47 * u, height: 46 * u)
            .clipShape(Circle())
            .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
            HStack(spacing: 7 * u) {
                heroEye
                heroEye
            }
            .offset(y: -6 * u)
            HStack(spacing: 24 * u) {
                Circle().fill(skinShade.opacity(0.45)).frame(width: 5 * u, height: 3.2 * u)
                Circle().fill(skinShade.opacity(0.45)).frame(width: 5 * u, height: 3.2 * u)
            }
            .offset(y: 3 * u)
            beard
            HStack(spacing: 1 * u) {
                Capsule().fill(Color(white: 0.90))
                    .frame(width: 9.5 * u, height: 4.5 * u)
                    .rotationEffect(.degrees(9))
                Capsule().fill(Color(white: 0.90))
                    .frame(width: 9.5 * u, height: 4.5 * u)
                    .rotationEffect(.degrees(-9))
            }
            .offset(y: 5.5 * u)
        }
    }

    var beard: some View {
        let shape = TaperedShape(topWidth: 0.75, bottomWidth: 1.05)
        return ZStack {
            shape.fill(Color(white: 0.92))
            shape.fill(Color(white: 0.78)).offset(x: 1.5 * u, y: 2 * u)
        }
        .frame(width: 24 * u, height: 16 * u)
        .clipShape(shape)
        .overlay(shape.stroke(outline, lineWidth: 1.6 * u))
        .offset(y: 12 * u)
    }

    /// Deep jade hat: leaning cone, wide brim, gold band and buckle.
    func wizardHat(starred: Bool) -> some View {
        ZStack {
            cel(ConeShape(), hatColor, lineWidth: 2.4, shift: 1.6)
                .frame(width: 40 * u, height: 30 * u)
                .rotationEffect(.degrees(-6))
                .offset(x: -2 * u, y: -34 * u)
            if starred {
                Image(systemName: "star.fill")
                    .font(.system(size: 5.5 * u))
                    .foregroundStyle(Color.questAmber)
                    .offset(x: -7 * u, y: -42 * u)
                Image(systemName: "star.fill")
                    .font(.system(size: 4.5 * u))
                    .foregroundStyle(Color.questAmber)
                    .offset(x: 5 * u, y: -36 * u)
                Image(systemName: "star.fill")
                    .font(.system(size: 3.5 * u))
                    .foregroundStyle(Color.questAmber)
                    .offset(x: -1 * u, y: -30 * u)
            }
            cel(Ellipse(), hatColor, lineWidth: 2.4, shift: 1.4)
                .frame(width: 56 * u, height: 11 * u)
                .offset(y: -22 * u)
            celFlat(Capsule(), .questAmber, lineWidth: 1.8)
                .frame(width: 24 * u, height: 5 * u)
                .offset(x: -1.5 * u, y: -29 * u)
            celFlat(Circle(), .questAmber, lineWidth: 1.5)
                .frame(width: 6 * u, height: 6 * u)
                .offset(x: -1.5 * u, y: -29 * u)
        }
    }

    // MARK: - Hood

    /// Shadow Hood: heavy cloth dome, dark opening, pale watching eyes.
    var hoodedHead: some View {
        ZStack {
            cel(ConeShape(), tunicColor.darker(0.16), lineWidth: 2.2, shift: 1.3)
                .frame(width: 16 * u, height: 15 * u)
                .rotationEffect(.degrees(-8))
                .offset(x: 2 * u, y: -27 * u)
            cel(Circle(), tunicColor.darker(0.08), lineWidth: 2.6, shift: 2.0)
                .frame(width: 56 * u, height: 52 * u)
                .offset(y: 2 * u)
            ZStack {
                FaceWindowShape()
                    .fill(Color(white: 0.10))
                    .overlay(FaceWindowShape().stroke(outline, lineWidth: 2 * u))
                    .frame(width: 40 * u, height: 30 * u)
                HStack(spacing: 9 * u) {
                    hoodEye
                    hoodEye
                }
                .offset(y: -3 * u)
            }
            .offset(y: -2 * u)
            // Hanging folds on the hood's shoulders.
            HStack(spacing: 26 * u) {
                celFlat(Capsule(), tunicColor.darker(0.24), lineWidth: 1.2)
                    .frame(width: 2 * u, height: 9 * u)
                celFlat(Capsule(), tunicColor.darker(0.24), lineWidth: 1.2)
                    .frame(width: 2 * u, height: 9 * u)
            }
            .offset(y: 20 * u)
            celFlat(Capsule(), charcoal, lineWidth: 1.6)
                .frame(width: 17 * u, height: 5 * u)
                .offset(y: 29 * u)
        }
    }

    var hoodEye: some View {
        ZStack {
            Ellipse().fill(Color(white: 0.86))
                .frame(width: 6.5 * u, height: 7.5 * u)
            Circle().fill(outline)
                .frame(width: 2.6 * u, height: 2.6 * u)
                .offset(x: 0.6 * u, y: 0.6 * u)
        }
    }
}
