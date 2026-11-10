//
//  VisionTextSignals.swift
//  PurgeQuest
//
//  The on-device text and barcode facts for one photo. VisionAnalysisService measures them; the
//  classifier only reads these three numbers, so they live in Foundation where the Linux harness can
//  build them.
//

import Foundation

/// On-device text/barcode signals for one photo.
struct VisionTextSignals: Sendable, Equatable {
    /// Total characters recognized across all text regions.
    let characterCount: Int
    /// Number of distinct text regions detected.
    let regionCount: Int
    /// Any machine-readable code (QR, EAN, DataMatrix, …) present.
    let hasBarcode: Bool
}
