//
//  ThumbnailTally.swift
//  PurgeQuest
//
//  What happened to the thumbnail requests of the last scan, and why the ones that failed did. A photo whose
//  thumbnail cannot be loaded is classed as broken media ("Null Portrait"), so when a real library fills with
//  them the owner needs to see the cause without a debugger. The tally is kept by the loader, saved when a scan
//  ends and read out on Settings. Foundation only, so the Linux harness checks it.
//

import Foundation

/// Why one thumbnail request came back with no image, as far as PhotoKit said.
nonisolated struct ThumbnailFailure: Hashable, Sendable {
    var cancelled: Bool = false
    var inCloud: Bool = false
    var errorDomain: String? = nil
    var errorCode: Int = 0

    /// A short plain label, the most specific cause first.
    var label: String {
        if cancelled { return "request cancelled" }
        if let errorDomain { return "error \(errorDomain) \(errorCode)" }
        if inCloud { return "in iCloud, not downloaded" }
        return "no reason given"
    }
}

nonisolated struct ThumbnailTally: Equatable, Sendable {
    /// Photos and videos asked for.
    private(set) var requested = 0
    /// Loaded, but only on the second request.
    private(set) var recovered = 0
    /// Not loaded after both requests.
    private(set) var failed = 0
    /// The cause of each final failure, counted by label.
    private(set) var reasons: [String: Int] = [:]

    mutating func recordLoaded(afterRetry: Bool) {
        requested += 1
        if afterRetry { recovered += 1 }
    }

    mutating func recordFailed(_ failure: ThumbnailFailure) {
        requested += 1
        failed += 1
        reasons[failure.label, default: 0] += 1
    }

    /// The text for Settings: how many failed, how many a second try saved, and the causes, most common first.
    var summary: String {
        guard requested > 0 else { return "No photos have been loaded yet." }
        if failed == 0 {
            return recovered == 0
                ? "All \(requested) loaded."
                : "All \(requested) loaded. \(recovered) needed a second try."
        }
        var lines = ["\(failed) of \(requested) could not be loaded. \(recovered) loaded on a second try."]
        let ordered = reasons.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        for (label, count) in ordered { lines.append("\(count) × \(label)") }
        return lines.joined(separator: "\n")
    }
}

/// The tally as the loader keeps it. Requests finish on several tasks at once, so it is guarded by a lock.
nonisolated final class ThumbnailTallyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var tally = ThumbnailTally()

    func reset() { lock.lock(); tally = ThumbnailTally(); lock.unlock() }
    func recordLoaded(afterRetry: Bool) { lock.lock(); tally.recordLoaded(afterRetry: afterRetry); lock.unlock() }
    func recordFailed(_ failure: ThumbnailFailure) { lock.lock(); tally.recordFailed(failure); lock.unlock() }
    var current: ThumbnailTally { lock.lock(); defer { lock.unlock() }; return tally }
}

/// Where the last scan's summary is kept, so Settings can show it after the scan is over.
nonisolated enum ThumbnailTallyStore {
    static let key = "pq.lastScan.thumbnails"

    static func save(_ tally: ThumbnailTally, to defaults: UserDefaults = .standard) {
        defaults.set(tally.summary, forKey: key)
    }

    static func loadSummary(from defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }
}
