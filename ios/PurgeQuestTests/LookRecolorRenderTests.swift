//
//  LookRecolorRenderTests.swift
//  PurgeQuestTests
//
//  The real renderer on the real art: what the skin, hair and armor-dye swatches do to a composited sprite frame.
//  App-hosted (needs the bundled sprites, manifest and masks), so it runs in Xcode and CI only; the planning
//  logic behind it is covered in LookRecolorTests and in the Linux harness.
//
//  Each check names the bug it catches. The old flat overlay fails the linework check (it tinted outlines), and
//  the swatches that wrote enums the renderer never read fail the "frames differ" checks.
//
//  Set SNAPSHOT_DIR (TEST_RUNNER_SNAPSHOT_DIR with xcodebuild, as CI does) to also save the looks from the
//  user's three screenshots as PNGs for a visual check.
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct LookRecolorRenderTests {

    // MARK: Helpers

    private struct Pixels {
        let width: Int
        let height: Int
        let rgba: [UInt8]

        func pixel(_ index: Int) -> (r: Int, g: Int, b: Int, a: Int) {
            (Int(rgba[index * 4]), Int(rgba[index * 4 + 1]), Int(rgba[index * 4 + 2]), Int(rgba[index * 4 + 3]))
        }

        var count: Int { width * height }
    }

    private func luma(_ p: (r: Int, g: Int, b: Int, a: Int)) -> Double {
        0.299 * Double(p.r) + 0.587 * Double(p.g) + 0.114 * Double(p.b)
    }

    /// One composited idle frame of a Seer paint, as 8-bit RGBA. `name` also exports a PNG when SNAPSHOT_DIR is set.
    private func render(_ look: HeroAppearance, variant: Int, name: String? = nil) throws -> Pixels {
        let frame = try #require(
            SpriteRenderer.shared.frame(race: .seer, variant: variant, animation: "Idle", frameIndex: 0, appearance: look))
        let cg = try #require(frame.image.cgImage)
        let width = cg.width, height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        try #require(drawn)
        if let name, let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let data = frame.image.pngData() {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        }
        return Pixels(width: width, height: height, rgba: bytes)
    }

    private var seer: HeroAppearance { HeroAppearance.default(for: .seer) }

    // MARK: Armor dye

    /// Bug: a flat overlay tinted the outlines and skin too. Dyed cloth keeps its linework and shading.
    @Test func dyeRecolorsTheOutfitAndLeavesTheLineworkAlone() throws {
        var dyed = seer
        dyed.armorDye = .verdigris
        let before = try render(seer, variant: 2)
        let after = try render(dyed, variant: 2, name: "look-dye-seer2-verdigris")
        #expect(before.width == after.width && before.height == after.height)

        var darkPixels = 0, darkChanged = 0, strongChanges = 0
        var greenBefore = 0.0, greenAfter = 0.0
        for index in 0..<before.count {
            let was = before.pixel(index), now = after.pixel(index)
            guard was.a > 200 else { continue }
            if was.r < 60 && was.g < 60 && was.b < 60 {
                darkPixels += 1
                if max(abs(now.r - was.r), abs(now.g - was.g), abs(now.b - was.b)) > 24 { darkChanged += 1 }
            }
            if abs(now.g - was.g) > 30 {
                strongChanges += 1
                greenBefore += Double(was.g - was.r)
                greenAfter += Double(now.g - now.r)
            }
        }
        #expect(darkPixels > 1000, "expected plenty of linework pixels to compare")
        #expect(Double(darkChanged) / Double(max(darkPixels, 1)) < 0.03, "the dye must not tint the outlines")
        #expect(strongChanges > 1000, "the dye must visibly recolor the outfit")
        #expect((greenAfter - greenBefore) / Double(max(strongChanges, 1)) > 25, "verdigris should make the outfit greener")
    }

    /// Bug: the dye repainting the hood. The head is never dyed.
    @Test func dyeNeverReachesTheHead() throws {
        var dyed = seer
        dyed.armorDye = .crimson
        let before = try render(seer, variant: 2)
        let after = try render(dyed, variant: 2)
        var worst = 0
        for y in 0..<(before.height * 35 / 100) {
            for x in 0..<before.width {
                let was = before.pixel(y * before.width + x), now = after.pixel(y * before.width + x)
                worst = max(worst, abs(now.r - was.r), abs(now.g - was.g), abs(now.b - was.b))
            }
        }
        #expect(worst <= 3, "the top of the frame is the hood; it must be identical with and without the dye")
    }

    // MARK: Skin tone

    /// Bug: a stale cached frame, or "As painted" leaving the recolor behind.
    @Test func skinToneRecolorsTheFaceAndAsPaintedRestoresTheArt() throws {
        let painted = try render(seer, variant: 2)
        let ebony = try render(seer.choosingSkin(.ebony), variant: 2, name: "look-skin-seer2-ebony")
        let restored = try render(seer.choosingSkin(.ebony).choosingSkin(nil), variant: 2)

        var darker = 0
        for index in 0..<painted.count where index / painted.width < painted.height * 6 / 10 {
            let was = painted.pixel(index), now = ebony.pixel(index)
            if was.a > 200 && luma(was) - luma(now) > 38 { darker += 1 }
        }
        #expect(darker > 1500, "the face window should take the darker tone")
        #expect(restored.rgba == painted.rgba, "As painted must restore the art, not leave the recolor")
    }

    // MARK: Hair color

    @Test func hairColorRecolorsSeerThreesHair() throws {
        let painted = try render(seer, variant: 3)
        let wheat = try render(seer.choosingHair(.wheat), variant: 3, name: "look-hair-seer3-wheat")
        var lighter = 0
        for index in 0..<painted.count where index / painted.width < painted.height * 55 / 100 {
            let was = painted.pixel(index), now = wheat.pixel(index)
            if was.a > 200 && luma(now) - luma(was) > 51 { lighter += 1 }
        }
        #expect(lighter > 3000, "the hair should turn wheat")
    }

    /// Bug: a control with nothing to change still altering the sprite (the old translucent blob).
    @Test func hairOnAHoodedPaintLeavesTheSpriteUntouched() throws {
        let painted = try render(seer, variant: 2)
        let wheat = try render(seer.choosingHair(.wheat), variant: 2)
        #expect(wheat.rgba == painted.rgba, "Seer 2 is hooded: there is no hair to recolor")
    }

    // MARK: The user's screenshots

    /// The reported bug: screenshots 2 and 3 differed only in the skin swatch and showed identical sprites.
    @Test func theThreeScreenshotLooksRenderAndTheSkinSwatchChangesTheSprite() throws {
        // Screenshot 1: Paint 2 with Verdigris armor dye, Raven hair, Honey skin.
        var first = seer.choosingSkin(.honey).choosingHair(.raven)
        first.armorDye = .verdigris
        _ = try render(first, variant: 2, name: "look-screenshot1-paint2-verdigris")
        // Screenshots 2 and 3: Paint 3, Jade hair, Honey then Jadekin skin.
        let honey = try render(seer.choosingSkin(.honey).choosingHair(.jade), variant: 3, name: "look-screenshot2-paint3-honey")
        let jadekin = try render(seer.choosingSkin(.jadekin).choosingHair(.jade), variant: 3, name: "look-screenshot3-paint3-jadekin")
        #expect(honey.rgba != jadekin.rgba, "changing the skin swatch must change the sprite")
    }
}
