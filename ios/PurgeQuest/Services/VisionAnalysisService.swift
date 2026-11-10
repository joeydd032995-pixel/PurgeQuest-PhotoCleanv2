//
//  VisionAnalysisService.swift
//  PurgeQuest
//
//  Rollout stage 5 — on-device Vision signals. One pass per photo detects
//  text density (documents and notes photographed instead of kept) and
//  embedded QR/barcodes (tickets, keys, one-time links — always review
//  material). Everything runs locally; only the tiny Sendable signal struct
//  (VisionTextSignals) leaves this file.
//

import Foundation
import UIKit
import Vision

enum VisionAnalysisService {

    /// Runs fast text recognition plus barcode detection in a single handler
    /// pass. Nil when the analysis fails — the classifier simply falls back to
    /// metadata rules.
    ///
    /// `@concurrent` is deliberate. The app builds with approachable concurrency, under which a plain
    /// `nonisolated async` function runs on the actor of whoever awaits it: here the main actor, so the
    /// recognition below, a synchronous and compute-heavy Vision call, would block the UI and run one
    /// photo at a time.
    ///
    /// `recognizeText: false` skips the text pass and only looks for codes. The classifier names a Live
    /// Photo or a screenshot before it ever reads how much text there is, so for those the text pass can
    /// never change the verdict; a code is checked first for every photo, so that pass always runs.
    @concurrent static func analyze(image: UIImage, recognizeText: Bool = true) async -> VisionTextSignals? {
        guard let cg = image.cgImage else { return nil }

        let barcode = VNDetectBarcodesRequest()
        barcode.symbologies = [.qr, .ean13, .ean8, .code128, .dataMatrix, .pdf417, .aztec]

        var requests: [VNRequest] = []
        var ocr: VNRecognizeTextRequest?
        if recognizeText {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            ocr = request
            requests.append(request)
        }
        requests.append(barcode)

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform(requests)
        } catch {
            return nil
        }

        let texts = (ocr?.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let characters = texts.reduce(0) { $0 + $1.count }
        let hasBarcode = !(barcode.results ?? []).isEmpty

        return VisionTextSignals(
            characterCount: characters,
            regionCount: texts.count,
            hasBarcode: hasBarcode
        )
    }
}
