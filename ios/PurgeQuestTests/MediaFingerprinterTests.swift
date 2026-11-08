//
//  MediaFingerprinterTests.swift
//  PurgeQuestTests
//
//  The UIKit half of duplicate detection: real pixels in, 64-bit hash out. The bit order itself
//  is pinned by DuplicateEngineTests (DHash); these tests pin the rendering in front of it, so a
//  change that silently alters stored hashes fails here.
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct MediaFingerprinterTests {

    /// An 8-bit grayscale image holding exactly these samples.
    private func grayImage(width: Int, height: Int, samples: [UInt8]) throws -> UIImage {
        let provider = try #require(CGDataProvider(data: Data(samples) as CFData))
        let cgImage = try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        return UIImage(cgImage: cgImage)
    }

    /// Two rising ramps with a sharp drop between them, drawn at any size. `mirrored` flips left and right.
    private func sawtooth(size: CGSize, mirrored: Bool = false, lift: Double = 0) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let width = Int(size.width)
            for x in 0..<width {
                var t = Double(x) / Double(width) * 2
                t -= t.rounded(.down)
                if mirrored { t = 1 - t }
                UIColor(white: min(1, 0.2 + 0.6 * t + lift), alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 1, height: Int(size.height)))
            }
        }
    }

    private func distance(_ a: UIImage, _ b: UIImage) throws -> Int {
        let hashA = try #require(MediaFingerprinter.dHash(image: a))
        let hashB = try #require(MediaFingerprinter.dHash(image: b))
        return DuplicateDetectionEngine.hammingDistance(hashA, hashB)
    }

    @Test func aNineByEightImageHashesToItsOwnSamples() throws {
        // No scaling happens at 9x8, so the hash must equal DHash over the same bytes.
        var samples: [UInt8] = []
        for i in 0..<72 { samples.append(UInt8((i * 37) % 251)) }
        let image = try grayImage(width: 9, height: 8, samples: samples)
        #expect(MediaFingerprinter.dHash(image: image) == DHash.hash(grayscale: samples))
    }

    @Test func theSameSceneAtTwoSizesHashesAlike() throws {
        let large = sawtooth(size: CGSize(width: 640, height: 480))
        let small = sawtooth(size: CGSize(width: 320, height: 240))
        #expect(try distance(large, small) <= DuplicateDetectionEngine.nearSimilarityThreshold)
    }

    @Test func aBrighterCopyHashesAlike() throws {
        let original = sawtooth(size: CGSize(width: 480, height: 360))
        let brighter = sawtooth(size: CGSize(width: 480, height: 360), lift: 0.12)
        #expect(try distance(original, brighter) <= DuplicateDetectionEngine.nearSimilarityThreshold)
    }

    @Test func aMirroredSceneHashesApart() throws {
        let original = sawtooth(size: CGSize(width: 480, height: 360))
        let mirrored = sawtooth(size: CGSize(width: 480, height: 360), mirrored: true)
        #expect(try distance(original, mirrored) > DuplicateDetectionEngine.nearSimilarityThreshold)
    }

    @Test func aFlatPictureHashesToNothingAndIsNotMatchable() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let flat = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        let hash = try #require(MediaFingerprinter.dHash(image: flat))
        #expect(hash == 0)
        #expect(!DuplicateDetectionEngine.isInformative(hash))
    }

    @Test func anImageWithoutPixelsHasNoHash() {
        #expect(MediaFingerprinter.dHash(image: UIImage()) == nil)
    }
}
