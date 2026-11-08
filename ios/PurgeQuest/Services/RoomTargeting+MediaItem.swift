//
//  RoomTargeting+MediaItem.swift
//  PurgeQuest
//
//  The thin bridge between a dive's MediaItem queue and the pure RoomTargeting rules.
//

import Foundation

extension RoomTargetFacts {
    /// The few fields of `item` that decide its buckets.
    init(item: MediaItem) {
        self.init(
            isVideo: item.kind == .video,
            isScreenshot: item.isScreenshot,
            sharpness: item.sharpness,
            durationSeconds: item.durationSeconds,
            estimatedBytes: item.estimatedBytes,
            creationDate: item.creationDate
        )
    }
}
