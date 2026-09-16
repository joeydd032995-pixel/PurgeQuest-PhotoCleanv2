//
//  MediaFingerprintRecord.swift
//  PurgeQuest
//
//  Persisted duplicate-detection fingerprint for one library asset. Stores
//  the perceptual hash and partial content hash so repeated dives never
//  re-hash the same media. Purely on-device.
//

import Foundation
import SwiftData

@Model
final class MediaFingerprintRecord {
    @Attribute(.unique) var assetIdentifier: String
    var byteSize: Int64
    /// 64-bit dHash stored as Int64 bit pattern; -1 means "not computed".
    var dHashBits: Int64
    /// Partial SHA-256 of the primary resource, when computed.
    var contentHash: String?
    var creationDate: Date?
    var computedAt: Date

    var dHash: UInt64? {
        dHashBits == -1 ? nil : UInt64(bitPattern: dHashBits)
    }

    init(assetIdentifier: String, byteSize: Int64, dHash: UInt64?, contentHash: String?, creationDate: Date?) {
        self.assetIdentifier = assetIdentifier
        self.byteSize = byteSize
        self.dHashBits = dHash.map(Int64.init(bitPattern:)) ?? -1
        self.contentHash = contentHash
        self.creationDate = creationDate
        self.computedAt = Date()
    }
}
