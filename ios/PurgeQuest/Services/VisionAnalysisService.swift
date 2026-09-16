//
//  VisionAnalysisService.swift
//  PurgeQuest
//
//  Rollout stage 5 — on-device Vision signals. One pass per photo detects
//  text density (documents and notes photographed instead of kept) and
//  embedded QR/barcodes (tickets, keys, one-time links — always review
//  material). Everything runs locally; only the tiny Sendable signal struct
//  leaves this file.
//

import Foundation
import UIKit
import Vision

/// On-device text/barcode signals for one photo.
struct VisionTextSignals: Sendable, Equatable {
    /// Total characters recognized across all text regions.
    let characterCount: Int
    /// Number of distinct text regions detected.
    let regionCount: Int
    /// Any machine-readable code (QR, EAN, DataMatrix, …) present.
    let hasBarcode: Bool
}

enum VisionAnalysisService {

    /// Runs fast text recognition plus barcode detection in a single handler
    /// pass on the cooperative pool. Nil when the analysis fails — the
    /// classifier simply falls back to metadata rules.
    nonisolated static func analyze(image: UIImage) async -> VisionTextSignals? {
        guard let cg = image.cgImage else { return nil }

        let ocr = VNRecognizeTextRequest()
        ocr.recognitionLevel = .fast
        ocr.usesLanguageCorrection = false

        let barcode = VNDetectBarcodesRequest()
        barcode.symbologies = [.qr, .ean13, .ean8, .code128, .dataMatrix, .pdf417, .aztec]

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([ocr, barcode])
        } catch {
            return nil
        }

        let texts = (ocr.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let characters = texts.reduce(0) { $0 + $1.count }
        let hasBarcode = !(barcode.results ?? []).isEmpty

        return VisionTextSignals(
            characterCount: characters,
            regionCount: texts.count,
            hasBarcode: hasBarcode
        )
    }
}
