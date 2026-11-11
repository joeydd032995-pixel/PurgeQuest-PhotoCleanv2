//
//  SpriteBodyBoundsTests.swift
//  PurgeQuestTests
//
//  Where the opaque part of a sprite sits inside its canvas. The hero is drawn on a canvas sized for
//  every animation frame, so the standing figure fills only part of it; this box is what lets a view
//  ask for the hero's own height.
//
//  Foundation only, so this runs in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct SpriteBodyBoundsTests {

    /// A `width` x `height` alpha buffer, opaque inside the given pixel box and clear outside it.
    private func buffer(width: Int, height: Int, box: (x: Int, y: Int, w: Int, h: Int), alpha: UInt8 = 255) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in box.y..<(box.y + box.h) {
            for x in box.x..<(box.x + box.w) {
                pixels[y * width + x] = alpha
            }
        }
        return pixels
    }

    @Test func aBlockIsFoundAsFractionsOfTheCanvasFromTheTopLeft() throws {
        let pixels = buffer(width: 10, height: 20, box: (x: 2, y: 5, w: 4, h: 10))
        let rect = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 10, height: 20))
        #expect(rect == NormalizedRect(x: 0.2, y: 0.25, width: 0.4, height: 0.5))
    }

    @Test func aSinglePixelIsOnePixelWideAndTall() throws {
        let pixels = buffer(width: 8, height: 4, box: (x: 7, y: 3, w: 1, h: 1))
        let rect = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 8, height: 4))
        #expect(rect == NormalizedRect(x: 0.875, y: 0.75, width: 0.125, height: 0.25))
    }

    @Test func aFullyOpaqueCanvasIsTheWholeCanvas() throws {
        let pixels = [UInt8](repeating: 255, count: 6 * 6)
        #expect(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 6, height: 6) == .full)
    }

    @Test func faintPixelsAtOrBelowTheThresholdAreNotPartOfTheBody() throws {
        // A soft shadow or an antialiasing fringe must not stretch the box.
        var pixels = buffer(width: 10, height: 10, box: (x: 4, y: 4, w: 2, h: 2))
        pixels[0] = SpriteBodyBounds.threshold            // top-left corner, exactly at the line: ignored
        let tight = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 10, height: 10))
        #expect(tight == NormalizedRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))

        pixels[0] = SpriteBodyBounds.threshold + 1        // one step over: counted
        let stretched = try #require(SpriteBodyBounds.normalizedRect(alpha: pixels, width: 10, height: 10))
        #expect(stretched == NormalizedRect(x: 0, y: 0, width: 0.6, height: 0.6))
    }

    @Test func anEmptyCanvasOrAMismatchedBufferHasNoBox() {
        #expect(SpriteBodyBounds.normalizedRect(alpha: [UInt8](repeating: 0, count: 16), width: 4, height: 4) == nil)
        #expect(SpriteBodyBounds.normalizedRect(alpha: [UInt8](repeating: 255, count: 15), width: 4, height: 4) == nil)
        #expect(SpriteBodyBounds.normalizedRect(alpha: [], width: 0, height: 0) == nil)
    }
}
