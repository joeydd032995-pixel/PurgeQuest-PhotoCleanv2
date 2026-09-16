//
//  MLAnalysisService.swift
//  PurgeQuest
//
//  Lightweight on-device signal extractors. Classification (which monster a
//  signal summons) lives in MonsterClassifier; this file only measures.
//  TODO: Replace the blur/luminance heuristics with CoreML
//  BlurClassifier.mlmodel + VideoQualityScorer.mlmodel when available.
//

import Foundation
import Photos
import UIKit
import CoreImage
import Vision

enum MLAnalysisService {

    // MARK: - Signal extractors

    /// Laplacian variance on a downsampled thumbnail — higher means sharper.
    nonisolated static func sharpnessVariance(image: UIImage) -> Double {
        guard let cg = image.cgImage else { return 100 }
        let target = CGSize(width: 80, height: 80)
        guard let scaled = downsample(cgImage: cg, to: target) else { return 100 }
        return laplacianVariance(cgImage: scaled)
    }

    /// Blur estimate on a downsampled thumbnail.
    nonisolated static func isLikelyBlurry(image: UIImage) -> Bool {
        sharpnessVariance(image: image) < 9.0
    }

    nonisolated static func averageLuminance(image: UIImage) -> Double {
        guard let cg = image.cgImage,
              let scaled = downsample(cgImage: cg, to: CGSize(width: 16, height: 16)) else { return 1.0 }
        let width = scaled.width
        let height = scaled.height
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

    private nonisolated static func laplacianVariance(cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 100 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var lum = [Double](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Double(pixels[i*4])
            let g = Double(pixels[i*4+1])
            let b = Double(pixels[i*4+2])
            lum[i] = 0.299*r + 0.587*g + 0.114*b
        }

        var values = [Double]()
        values.reserveCapacity((width - 2) * (height - 2))
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let c = lum[y * width + x]
                let up = lum[(y - 1) * width + x]
                let dn = lum[(y + 1) * width + x]
                let lf = lum[y * width + (x - 1)]
                let rt = lum[y * width + (x + 1)]
                let v = (up + dn + lf + rt) - 4 * c
                values.append(v)
            }
        }
        guard !values.isEmpty else { return 100 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance
    }
}
