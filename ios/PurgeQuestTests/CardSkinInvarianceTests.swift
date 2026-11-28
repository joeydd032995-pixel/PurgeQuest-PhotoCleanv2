import Testing
import SwiftUI
import UIKit
@testable import PurgeQuest

/// The promise every card effect makes (design section 3.3, invariant 1): at rest, the photo is never touched. Each of
/// the six skins, together with the combo rim and the Live Photo glow, is drawn over a flat photo and compared with the
/// same card carrying nothing; every pixel inside the photo must be identical. A flat colour is the sharpest probe: any
/// tint, shadow, glow, particle or line that reaches it changes a pixel.
@MainActor
@Suite struct CardSkinInvarianceTests {

    private let photoColor = Color(red: 0.2, green: 0.4, blue: 0.8)
    private let cardSize = CGSize(width: 300, height: 300)
    /// The plain card's photo starts 12 pt in (8 pt card padding, 4 pt rim); a skin's rim is 2 pt wider (4 for the
    /// Behemoths), so its photo starts at 14 or 16. Compared from 20, inside every one of them.
    private let interior = CGRect(x: 20, y: 20, width: 260, height: 260)

    /// The card as the combat card builds it: the frame inside the card's 8 pt padding, with the edge layer over all of it.
    private func card(skin: FamilySkinKind?, dressed: Bool) -> some View {
        let combo: ComboRimState? = dressed
            ? ComboRimState(tier: ComboTier(tenths: 20), pulse: 1, sheen: 0.5, cool: 0.5, shown: 1)
            : nil
        return ExhibitFrame(
            chip: nil,
            accent: Color.questAmber,
            skin: skin,
            skinSeed: "invariance",
            crack: dressed ? 1 : 0,
            combo: combo,
            liveGlow: dressed ? 1 : 0
        ) {
            photoColor
        }
        .padding(8)
        .overlay {
            if dressed, let skin {
                SkinEdgeLayer(
                    kind: skin,
                    seedKey: "invariance",
                    accent: Color.questAmber,
                    gate: .live,
                    isFront: true,
                    dragX: -80,
                    dragY: 0,
                    lift: 1,
                    burstStart: Date()
                )
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .background(Color.black)
    }

    private struct Pixels {
        let data: [UInt8]
        let width: Int
        let height: Int
    }

    private func render(_ view: some View) -> Pixels? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.cgImage else { return nil }
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Pixels(data: data, width: width, height: height) : nil
    }

    /// How many pixels differ, inside `region` or (when `region` is nil) anywhere.
    private func mismatches(_ a: Pixels, _ b: Pixels, in region: CGRect?) -> Int {
        var count = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                if let region, !region.contains(CGPoint(x: x, y: y)) { continue }
                let i = (y * a.width + x) * 4
                if a.data[i] != b.data[i] || a.data[i + 1] != b.data[i + 1]
                    || a.data[i + 2] != b.data[i + 2] || a.data[i + 3] != b.data[i + 3] {
                    count += 1
                }
            }
        }
        return count
    }

    @Test func noSkinComboOrGlowEverTouchesThePhotoAtRest() throws {
        let baseline = try #require(render(card(skin: nil, dressed: false)), "the plain card rendered")
        for kind in FamilySkinKind.allCases {
            let dressed = try #require(render(card(skin: kind, dressed: true)), "\(kind) rendered")
            #expect(dressed.width == baseline.width && dressed.height == baseline.height)
            let inside = mismatches(baseline, dressed, in: interior)
            #expect(inside == 0, "\(kind): \(inside) photo pixels changed")
            let overall = mismatches(baseline, dressed, in: nil)
            #expect(overall > 0, "\(kind): nothing was drawn at all, so this test would prove nothing")
        }
    }
}
