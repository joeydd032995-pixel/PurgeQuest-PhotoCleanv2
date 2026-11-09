//
//  StorageMeasurementService.swift
//  PurgeQuest
//
//  Reports the space PurgeQuest has ACTUALLY reclaimed: the confirmed
//  increase in the device's free storage, measured separately from the
//  byte estimates the dungeon banks. The estimate ("pending" and
//  "opportunity" numbers) can drift from reality; only a measured drop in
//  used storage counts as reclaimed.
//
//  How verification works: the service remembers the free space observed at
//  the first measurement after the latest verification. When a later reading
//  shows free space grew past a noise threshold (caches, iCloud sync, and
//  system bookkeeping make small swings meaningless), the gain is banked as
//  verified and the baseline rolls forward. If free space instead shrinks —
//  the user took photos, apps downloaded — the earlier unverified gain is
//  masked, so the baseline quietly follows it down.
//

import Foundation
import os

@MainActor
final class StorageMeasurementService {
    static let shared = StorageMeasurementService()
    private init() {}

    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "PurgeQuest", category: "Storage")

    /// Free-space gains smaller than this are noise, not reclaimed media.
    private let verificationThreshold: Int64 = 32 * 1_048_576

    private static let baselineKey = "storage.baselineFreeBytes"
    private static let verifiedKey = "storage.verifiedReclaimedBytes"

    /// Lifetime total of confirmed reclaimed space.
    private(set) var verifiedBytes: Int64 = (UserDefaults.standard.object(forKey: StorageMeasurementService.verifiedKey) as? NSNumber)?.int64Value ?? 0

    /// Free space observed at the last baseline reset; nil until the first reading.
    private var baselineFreeBytes: Int64? {
        get { defaults.object(forKey: Self.baselineKey) as? Int64 }
        set { newValue.map { defaults.set($0, forKey: Self.baselineKey) } ?? defaults.removeObject(forKey: Self.baselineKey) }
    }

    /// One reading of the reclaim ledger.
    struct Reading: Equatable {
        /// Lifetime confirmed reclaimed space.
        var verifiedBytes: Int64
        /// Growth since the baseline that has not yet cleared the noise threshold.
        var unverifiedBytes: Int64
        /// False when the device's free space could not be read at all.
        var isMeasurable: Bool
    }

    var currentReading: Reading {
        Reading(verifiedBytes: verifiedBytes, unverifiedBytes: pendingUnverified, isMeasurable: lastReadingMeasurable)
    }

    private var pendingUnverified: Int64 = 0
    private var lastReadingMeasurable = true



    /// Takes a fresh free-space reading and updates the ledger. Call on each
    /// dashboard visit: Recently Deleted drains after 30 days and when the
    /// user empties it manually, which is exactly when freed space shows up.
    @discardableResult
    func refresh() -> Reading {
        guard let free = deviceFreeBytes() else {
            lastReadingMeasurable = false
            log.error("could not read device free space")
            return currentReading
        }
        lastReadingMeasurable = true

        let baseline = baselineFreeBytes ?? free
        if baselineFreeBytes == nil {
            log.info("storage baseline set at \(free, privacy: .public) bytes")
        }
        baselineFreeBytes = min(baseline, free)

        let gain = free - baseline
        if gain >= verificationThreshold {
            verifiedBytes += gain
            baselineFreeBytes = free
            pendingUnverified = 0
            log.info("verified \(gain, privacy: .public) bytes reclaimed; lifetime \(self.verifiedBytes, privacy: .public)")
        } else {
            pendingUnverified = max(0, gain)
        }
        return currentReading
    }

    /// Test hook: clears the ledger so a fresh install state can be simulated.
    func resetForTesting() {
        defaults.removeObject(forKey: Self.baselineKey)
        defaults.removeObject(forKey: Self.verifiedKey)
        verifiedBytes = 0
        pendingUnverified = 0
    }

    /// Free space right now, using the volume metric iOS's own storage
    /// screen treats as authoritative (includes purgeable space that matters).
    private func deviceFreeBytes() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return Int64(free)
    }
}
