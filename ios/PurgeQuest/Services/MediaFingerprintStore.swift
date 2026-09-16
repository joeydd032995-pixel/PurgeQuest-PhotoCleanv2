//
//  MediaFingerprintStore.swift
//  PurgeQuest
//
//  Persistence for duplicate-detection fingerprints so repeated dives never
//  re-hash the same media. Purely on-device.
//

import Foundation
import SwiftData

@MainActor
enum MediaFingerprintStore {

    static func loadCached(in context: ModelContext) -> [String: MediaFingerprintRecord] {
        let all = (try? context.fetch(FetchDescriptor<MediaFingerprintRecord>())) ?? []
        return Dictionary(all.map { ($0.assetIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Inserts new fingerprints and back-fills hashes for known assets.
    static func persist(_ fingerprints: [MediaFingerprint], in context: ModelContext) {
        guard !fingerprints.isEmpty else { return }
        let existing = loadCached(in: context)
        var didChange = false
        for f in fingerprints {
            if let record = existing[f.assetID] {
                if record.contentHash == nil, let hash = f.contentHash {
                    record.contentHash = hash
                    didChange = true
                }
                if record.dHash == nil, let dh = f.dHash {
                    record.dHashBits = Int64(bitPattern: dh)
                    didChange = true
                }
            } else {
                context.insert(MediaFingerprintRecord(
                    assetIdentifier: f.assetID,
                    byteSize: f.byteSize,
                    dHash: f.dHash,
                    contentHash: f.contentHash,
                    creationDate: f.creationDate
                ))
                didChange = true
            }
        }
        if didChange { try? context.save() }
    }
}
