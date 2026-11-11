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
import os

enum VisionAnalysisService {

    /// How long a scan waits for one photo's pass. On a phone the pass takes a fraction of a second, so
    /// this is a ceiling for a system that has stopped answering, not a budget.
    nonisolated static let deadline: TimeInterval = 8

    /// Where the blocking Vision call runs: a dispatch queue, never the cooperative pool. See BlockingCall.
    private nonisolated static let queue = DispatchQueue(label: "PurgeQuest.vision", qos: .userInitiated, attributes: .concurrent)

    private nonisolated static let log = Logger(subsystem: "PurgeQuest", category: "Vision")

    /// A CGImage handed to the dispatch queue once and not touched here afterwards.
    private struct Frame: @unchecked Sendable {
        let image: CGImage
    }

    /// Runs fast text recognition plus barcode detection in a single handler
    /// pass. Nil when the analysis fails or is skipped — the classifier simply
    /// falls back to metadata rules.
    ///
    /// Vision's `perform` is synchronous and blocks its thread until its own work is done. Run on the
    /// cooperative pool, four of them at once could park every pool thread in the same wait, which stopped
    /// a dive at "Summoning monsters…" on a three-core CI runner (see BlockingCall). So the call runs on
    /// its own dispatch queue, and this function only suspends until it answers or `deadline` passes.
    /// `@concurrent` stays so that the little work done here never runs on the main actor: the app builds
    /// with approachable concurrency, under which a plain `nonisolated async` function runs on the actor
    /// of whoever awaits it.
    ///
    /// When the deadline passes the scan's `tripwire` is tripped: this photo and every photo that has not
    /// started yet go without text and code signals, so a Vision that has stopped answering costs one
    /// deadline, not one per photo.
    ///
    /// `recognizeText: false` skips the text pass and only looks for codes. The classifier names a Live
    /// Photo or a screenshot before it ever reads how much text there is, so for those the text pass can
    /// never change the verdict; a code is checked first for every photo, so that pass always runs.
    @concurrent static func analyze(
        image: UIImage,
        recognizeText: Bool = true,
        tripwire: BlockingCall.Tripwire = BlockingCall.Tripwire()
    ) async -> VisionTextSignals? {
        guard !tripwire.isTripped, let cg = image.cgImage else { return nil }

        let frame = Frame(image: cg)
        let outcome = await BlockingCall.run(on: queue, within: deadline) {
            recognize(frame.image, recognizeText: recognizeText)
        }
        switch outcome {
        case .finished(let signals):
            return signals
        case .timedOut:
            tripwire.trip()
            log.error("vision: no answer within \(deadline, format: .fixed(precision: 0), privacy: .public) s; this scan goes on without text and code signals")
            return nil
        }
    }

    /// The Vision pass itself. Blocks until Vision is done, so it is only ever called from `queue`.
    private nonisolated static func recognize(_ cg: CGImage, recognizeText: Bool) -> VisionTextSignals? {
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
