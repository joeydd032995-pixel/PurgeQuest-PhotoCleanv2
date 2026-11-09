//
//  MLAnalysisService.swift
//  PurgeQuest
//
//  Lightweight on-device signal extractors. Classification (which monster a
//  signal summons) lives in MonsterClassifier; this file only measures.
//  TODO: Compare ThumbnailAnalysis' focus score with a CoreML
//  BlurClassifier.mlmodel + VideoQualityScorer.mlmodel when available.
//

import Foundation
import Photos
import UIKit
import CoreImage
import Vision

enum MLAnalysisService {

    // MARK: - Signal extractors

    /// Focus, exposure and the duplicate signature of a thumbnail, from a single 256×256 gray render
    /// (see ThumbnailAnalysis, which does the arithmetic and is tested on Linux). Runs off the main
    /// actor: with the app's approachable-concurrency settings a plain `nonisolated async` function
    /// would run on its caller's actor, and this is the heaviest per-photo computation on that path.
    /// Nil when the image has no bitmap to read.
    @concurrent static func thumbnailMetrics(for image: UIImage) async -> ThumbnailMetrics? {
        guard let cg = image.cgImage else { return nil }
        let side = ThumbnailAnalysis.side
        guard let ctx = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        // High-quality downscaling averages the pixels it drops. Anything cheaper samples them, and
        // sampling invents fine detail that a focus measure would read as sharpness.
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = ctx.data else { return nil }
        let count = side * side
        let samples = UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: count), count: count)
        return ThumbnailAnalysis.metrics(grayscale: Array(samples), side: side)
    }

    /// Mean 0…1 luminance of any CGImage (16×16 readback).
    nonisolated static func averageLuminance(cgImage: CGImage) -> Double {
        let width = 16
        let height = 16
        guard let scaled = downsample(cgImage: cgImage, to: CGSize(width: width, height: height)) else { return 1.0 }
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 1.0 }
        ctx.draw(scaled, in: CGRect(x: 0, y: 0, width: width, height: height))
        var total = 0.0
        let count = width * height
        for i in 0..<count {
            let r = Double(pixels[i*4]) / 255.0
            let g = Double(pixels[i*4+1]) / 255.0
            let b = Double(pixels[i*4+2]) / 255.0
            total += 0.299*r + 0.587*g + 0.114*b
        }
        return total / Double(count)
    }

    private nonisolated static func downsample(cgImage: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
