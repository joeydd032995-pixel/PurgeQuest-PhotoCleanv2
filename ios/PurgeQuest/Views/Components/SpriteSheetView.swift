//
//  SpriteSheetView.swift
//  PurgeQuest
//
//  Draws one frame at a time from a horizontal sprite sheet in the asset
//  catalog. Used for the Wraith monsters, the Forest Spirit pets and the
//  Phantom Purge event decor. The sheets are listed in `SpriteArt`.
//

import SwiftUI

/// A horizontal strip of equally wide frames stored as one image.
nonisolated struct SpriteSheet: Sendable, Equatable {
    let asset: String
    let frames: Int
    /// One frame's size in sheet pixels. Only the ratio is used for layout.
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let fps: Double
    /// Pixel art is drawn with nearest-neighbour scaling so it stays crisp.
    let pixelArt: Bool

    var aspect: CGFloat { cellWidth / cellHeight }

    /// Which frame to show at a moment in time. Pure, so it can be tested.
    func frameIndex(at date: Date) -> Int {
        guard frames > 1, fps > 0 else { return 0 }
        let tick = Int((date.timeIntervalSinceReferenceDate * fps).rounded(.down))
        return ((tick % frames) + frames) % frames
    }
}

struct SpriteSheetView: View {
    let sheet: SpriteSheet
    /// Height of one frame on screen; the width follows the frame's aspect.
    let height: CGFloat
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = height * sheet.aspect
        Group {
            if animated && !reduceMotion && sheet.frames > 1 && sheet.fps > 0 {
                TimelineView(.periodic(from: .now, by: 1 / sheet.fps)) { context in
                    frame(index: sheet.frameIndex(at: context.date), width: width)
                }
            } else {
                frame(index: 0, width: width)
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func frame(index: Int, width: CGFloat) -> some View {
        Image(sheet.asset)
            .resizable()
            .interpolation(sheet.pixelArt ? .none : .high)
            .frame(width: width * CGFloat(sheet.frames), height: height)
            .offset(x: -width * CGFloat(index))
            .frame(width: width, height: height, alignment: .leading)
            .clipped()
    }
}

/// Every sprite sheet the app ships beyond the legacy vector art.
/// `tools/ci/repo_guard.py` checks each one against its image in the asset catalog.
nonisolated enum SpriteArt {

    // MARK: Wraith monsters (Craftpix "Wraith" tiny-style pack, idle loop)

    static let mistWraith = SpriteSheet(asset: "Monster-mistWraith", frames: 12, cellWidth: 112, cellHeight: 160, fps: 10, pixelArt: false)
    static let tatterWraith = SpriteSheet(asset: "Monster-tatterWraith", frames: 12, cellWidth: 118, cellHeight: 160, fps: 10, pixelArt: false)
    static let voidWraith = SpriteSheet(asset: "Monster-voidWraith", frames: 12, cellWidth: 117, cellHeight: 160, fps: 10, pixelArt: false)

    static func monsterSheet(for type: MonsterType) -> SpriteSheet? {
        switch type {
        case .mistWraith:   return mistWraith
        case .tatterWraith: return tatterWraith
        case .voidWraith:   return voidWraith
        default:            return nil
        }
    }

    // MARK: Forest Spirit pets (pixel art, idle loop)

    static let spiritBlue = SpriteSheet(asset: "Pet-spiritBlue", frames: 8, cellWidth: 13, cellHeight: 21, fps: 6, pixelArt: true)
    static let spiritGreen = SpriteSheet(asset: "Pet-spiritGreen", frames: 8, cellWidth: 13, cellHeight: 21, fps: 6, pixelArt: true)
    static let spiritRed = SpriteSheet(asset: "Pet-spiritRed", frames: 8, cellWidth: 13, cellHeight: 21, fps: 6, pixelArt: true)
    static let spiritYellow = SpriteSheet(asset: "Pet-spiritYellow", frames: 8, cellWidth: 13, cellHeight: 21, fps: 6, pixelArt: true)

    // MARK: Phantom Purge event pieces (LumioLab Halloween sampler)

    static let ghost = SpriteSheet(asset: "Halloween-ghost", frames: 12, cellWidth: 48, cellHeight: 64, fps: 10, pixelArt: true)
    static let bat = SpriteSheet(asset: "Halloween-bat", frames: 6, cellWidth: 34, cellHeight: 24, fps: 14, pixelArt: true)
    static let jackOLantern = SpriteSheet(asset: "Halloween-jackOLantern", frames: 8, cellWidth: 44, cellHeight: 40, fps: 8, pixelArt: true)
    static let candyCorn = SpriteSheet(asset: "Halloween-candyCorn", frames: 8, cellWidth: 22, cellHeight: 26, fps: 10, pixelArt: true)
    static let gravestone = SpriteSheet(asset: "Halloween-gravestone", frames: 1, cellWidth: 40, cellHeight: 52, fps: 0, pixelArt: true)
    static let cobweb = SpriteSheet(asset: "Halloween-cobweb", frames: 1, cellWidth: 48, cellHeight: 48, fps: 0, pixelArt: true)

    /// Companion sprites by cosmetic id, with how tall to draw them beside the hero.
    static func petSheet(id: String) -> (sheet: SpriteSheet, height: CGFloat)? {
        switch id {
        case "pet.spiritBlue":   return (spiritBlue, 22)
        case "pet.spiritGreen":  return (spiritGreen, 22)
        case "pet.spiritRed":    return (spiritRed, 22)
        case "pet.spiritYellow": return (spiritYellow, 22)
        case "pet.ghost":        return (ghost, 26)
        case "pet.bat":          return (bat, 14)
        default:                 return nil
        }
    }

    /// Every sheet, for the asset checks.
    static let all: [SpriteSheet] = [
        mistWraith, tatterWraith, voidWraith,
        spiritBlue, spiritGreen, spiritRed, spiritYellow,
        ghost, bat, jackOLantern, candyCorn, gravestone, cobweb
    ]
}
