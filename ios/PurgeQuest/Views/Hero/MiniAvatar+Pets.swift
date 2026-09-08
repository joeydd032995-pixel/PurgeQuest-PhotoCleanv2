//
//  MiniAvatar+Pets.swift
//  PurgeQuest
//
//  Companion pets and delete-burst effects for the chunky hero figure,
//  drawn with the shared cel system so they read as part of the same cast.
//

import SwiftUI

extension MiniAvatarView {

    // MARK: - Pets

    @ViewBuilder var petLayer: some View {
        if let pet = item(.pet) {
            petModel(id: pet.id, color: petColor)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    @ViewBuilder func petModel(id: String, color: Color) -> some View {
        switch id {
        case "pet.owl": nocturneOwl
        case "pet.reel": reelSpirit
        case "pet.beachSpirit": beachSpirit
        default: pixelFamiliar(color)
        }
    }

    /// Pixel Familiar: chunky slime-cat scout with square eyes.
    func pixelFamiliar(_ color: Color) -> some View {
        ZStack {
            // Ears.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                cel(ConeShape(), color, lineWidth: 1.6, shift: 0.8)
                    .frame(width: 5.5 * u, height: 6.5 * u)
                    .rotationEffect(.degrees(side * -12))
                    .offset(x: side * 5 * u, y: 34 * u)
            }
            cel(RoundedRectangle(cornerRadius: 5 * u, style: .continuous), color, lineWidth: 2.2, shift: 1.3)
                .frame(width: 17 * u, height: 14 * u)
                .offset(y: 44 * u)
            // Pixel eyes: hard white squares with dark pupils.
            HStack(spacing: 4 * u) {
                ZStack {
                    Rectangle().fill(Color(white: 0.96)).frame(width: 3.2 * u, height: 3.2 * u)
                    Rectangle().fill(outline).frame(width: 1.6 * u, height: 1.6 * u)
                        .offset(x: 0.4 * u, y: 0.4 * u)
                }
                ZStack {
                    Rectangle().fill(Color(white: 0.96)).frame(width: 3.2 * u, height: 3.2 * u)
                    Rectangle().fill(outline).frame(width: 1.6 * u, height: 1.6 * u)
                        .offset(x: 0.4 * u, y: 0.4 * u)
                }
            }
            .offset(y: 43 * u)
        }
        .offset(x: -41 * u)
    }

    /// Reel Spirit: hovering film reel with a trailing film tail.
    var reelSpirit: some View {
        ZStack {
            HStack(spacing: 1 * u) {
                Rectangle().fill(Color.videoSapphire.darker(0.2)).frame(width: 2 * u, height: 5 * u)
                Rectangle().fill(Color.videoSapphire.darker(0.2)).frame(width: 2 * u, height: 3.5 * u)
                Rectangle().fill(Color.videoSapphire.darker(0.2)).frame(width: 2 * u, height: 4.5 * u)
            }
            .offset(y: 13 * u)
            cel(Circle(), .videoSapphire, lineWidth: 2.2, shift: 1.4)
                .frame(width: 16 * u, height: 16 * u)
            ForEach(0..<6, id: \.self) { i in
                Circle().fill(Color(white: 0.95))
                    .frame(width: 2 * u, height: 2 * u)
                    .offset(y: -6.2 * u)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            Circle().fill(Color.videoSapphire.darker(0.30))
                .frame(width: 3 * u, height: 3 * u)
        }
        .offset(x: -42 * u, y: -2 * u)
    }

    /// Nocturne Owl: chubby dome, pale eyes, gold beak and feet.
    var nocturneOwl: some View {
        ZStack {
            // Ear tufts.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                cel(ConeShape(), Color(red: 0.56, green: 0.41, blue: 0.24), lineWidth: 1.4, shift: 0.8)
                    .frame(width: 4.5 * u, height: 5.5 * u)
                    .offset(x: side * 5.5 * u, y: 30.5 * u)
            }
            // Body dome.
            cel(Circle(), Color(red: 0.56, green: 0.41, blue: 0.24), lineWidth: 2.2, shift: 1.4)
                .frame(width: 18 * u, height: 20 * u)
                .offset(y: 42 * u)
            // Belly.
            Ellipse().fill(Color(red: 0.78, green: 0.66, blue: 0.48))
                .frame(width: 10 * u, height: 11 * u)
                .offset(y: 46 * u)
            // Wings.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                Ellipse().fill(Color(red: 0.44, green: 0.31, blue: 0.18))
                    .frame(width: 4.5 * u, height: 12 * u)
                    .offset(x: side * 7.5 * u, y: 43 * u)
            }
            // Eyes.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                ZStack {
                    Circle().fill(Color(white: 0.95)).frame(width: 7 * u, height: 7 * u)
                    Circle().fill(outline).frame(width: 3 * u, height: 3 * u)
                        .offset(x: side * 0.5 * u, y: 0.5 * u)
                }
                .offset(x: side * 4 * u, y: 37 * u)
            }
            // Beak.
            celFlat(DiamondShape(), .questAmber, lineWidth: 1.2)
                .frame(width: 3.4 * u, height: 3.4 * u)
                .offset(y: 41.5 * u)
            // Feet.
            HStack(spacing: 6 * u) {
                Capsule().fill(Color.questAmber).frame(width: 3.4 * u, height: 1.6 * u)
                Capsule().fill(Color.questAmber).frame(width: 3.4 * u, height: 1.6 * u)
            }
            .offset(y: 52.5 * u)
        }
        .offset(x: -42 * u)
    }

    /// Beach Spirit: a wave-shaped companion with a foam crest.
    var beachSpirit: some View {
        ZStack {
            cel(Circle(), Color(red: 0.40, green: 0.68, blue: 0.76), lineWidth: 2.2, shift: 1.3)
                .frame(width: 19 * u, height: 16 * u)
                .offset(y: 44 * u)
            ZStack {
                Circle().fill(Color(white: 0.96)).frame(width: 5.5 * u, height: 5.5 * u)
                    .offset(x: -4 * u, y: -4 * u)
                Circle().fill(Color(white: 0.96)).frame(width: 4.4 * u, height: 4.4 * u)
                    .offset(x: 0.5 * u, y: -5.5 * u)
                Circle().fill(Color(white: 0.96)).frame(width: 3.6 * u, height: 3.6 * u)
                    .offset(x: 5 * u, y: -3.5 * u)
            }
            .offset(y: 40 * u)
            HStack(spacing: 4 * u) {
                Circle().fill(outline).frame(width: 2 * u, height: 2.6 * u)
                Circle().fill(outline).frame(width: 2 * u, height: 2.6 * u)
            }
            .offset(y: 45 * u)
        }
        .offset(x: -42 * u)
    }

    // MARK: - Effects

    @ViewBuilder var fxLayer: some View {
        if let fx = item(.effect) {
            fxParticles(id: fx.id)
                .transition(.opacity)
        }
    }

    @ViewBuilder func fxParticles(id: String) -> some View {
        switch id {
        case "fx.sparks":
            spark(.questAmber, size: 6, at: CGPoint(x: -34, y: -52))
            spark(.questAmber, size: 4, at: CGPoint(x: -43, y: -40))
            spark(.questAmber, size: 3, at: CGPoint(x: -27, y: -61))
        case "fx.filmstrip":
            filmCell(at: CGPoint(x: -36, y: -52), size: 7)
            filmCell(at: CGPoint(x: -44, y: -38), size: 5)
            filmCell(at: CGPoint(x: -28, y: -61), size: 4)
        case "fx.aurora":
            auroraBar(.xpViolet, width: 13, at: CGPoint(x: -36, y: -52), angle: -30)
            auroraBar(.videoSapphire, width: 10, at: CGPoint(x: -45, y: -40), angle: -30)
        case "fx.spectral":
            wisp(width: 9, height: 12, at: CGPoint(x: -36, y: -50), opacity: 0.95)
            wisp(width: 6.5, height: 8.5, at: CGPoint(x: -44, y: -36), opacity: 0.7)
        case "fx.confetti":
            confetti(.questAmber, size: 4.5, at: CGPoint(x: -34, y: -54), angle: 18)
            confetti(.gemEmerald, size: 3.5, at: CGPoint(x: -43, y: -42), angle: -24)
            confetti(.combatCrimson, size: 3.5, at: CGPoint(x: -27, y: -61), angle: 40)
            confetti(.videoSapphire, size: 3, at: CGPoint(x: -48, y: -52), angle: -10)
        case "fx.hearts":
            heart(size: 8, at: CGPoint(x: -35, y: -52))
            heart(size: 5.5, at: CGPoint(x: -44, y: -40))
            heart(size: 4, at: CGPoint(x: -27, y: -61), faded: true)
        default:
            EmptyView()
        }
    }

    /// Chunky gold spark.
    func spark(_ color: Color, size: CGFloat, at point: CGPoint) -> some View {
        cel(DiamondShape(), color, lineWidth: 1.4, shift: 0.7)
            .frame(width: size * u, height: size * u)
            .offset(x: point.x * u, y: point.y * u)
    }

    /// Video-themed film cell with a lit inner frame.
    func filmCell(at point: CGPoint, size: CGFloat) -> some View {
        celFlat(RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous), .videoSapphire, lineWidth: 1.4)
            .frame(width: size * u, height: size * 0.8 * u)
            .overlay(
                Rectangle()
                    .fill(Color(white: 0.9).opacity(0.6))
                    .frame(width: size * 0.5 * u, height: size * 0.28 * u)
            )
            .offset(x: point.x * u, y: point.y * u)
    }

    /// Cool-toned aurora trail bar.
    func auroraBar(_ color: Color, width: CGFloat, at point: CGPoint, angle: Double) -> some View {
        celFlat(Capsule(), color, lineWidth: 1.2)
            .frame(width: width * u, height: 3 * u)
            .rotationEffect(.degrees(angle))
            .offset(x: point.x * u, y: point.y * u)
    }

    /// Pale spectral wisp.
    func wisp(width: CGFloat, height: CGFloat, at point: CGPoint, opacity: Double) -> some View {
        celFlat(WispShape(), Color(white: 0.92).opacity(opacity), lineWidth: 1.2)
            .frame(width: width * u, height: height * u)
            .offset(x: point.x * u, y: point.y * u)
    }

    /// Confetti square.
    func confetti(_ color: Color, size: CGFloat, at point: CGPoint, angle: Double) -> some View {
        celFlat(Rectangle(), color, lineWidth: 1.2)
            .frame(width: size * u, height: size * u)
            .rotationEffect(.degrees(angle))
            .offset(x: point.x * u, y: point.y * u)
    }

    /// Valentine heart trail.
    func heart(size: CGFloat, at point: CGPoint, faded: Bool = false) -> some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size * u, weight: .black))
            .foregroundStyle(Color.combatCrimson.opacity(faded ? 0.65 : 1))
            .offset(x: point.x * u, y: point.y * u)
    }
}
