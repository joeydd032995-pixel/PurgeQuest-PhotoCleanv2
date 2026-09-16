//
//  MediaItem.swift
//  PurgeQuest
//
//  Unified, in-memory model for a fetched photo or video, paired with its
//  monster classification and the cheap signals the classifier relies on.
//

import Foundation
import Photos
import UIKit

/// Unified, in-memory model for a fetched photo or video, paired with its monster classification.
struct MediaItem: Identifiable, Equatable {
    let id: String                  // localIdentifier
    let kind: MediaKind
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let durationSeconds: Double      // 0 for photos
    let estimatedBytes: Int64
    let isFavorite: Bool
    let playbackStyle: Int           // PHAsset.PlaybackStyle.rawValue

    // Cheap explainability signals captured at fetch time.
    var isScreenshot: Bool = false
    var hasEdits: Bool = false
    var isScreenRecording: Bool = false
    var isLivePhoto: Bool = false
    var isLooping: Bool = false
    var isHighFrameRate: Bool = false
    var sharpness: Double? = nil     // Laplacian variance of the thumbnail
    var luminance: Double? = nil     // Average thumbnail luminance

    var monsterType: MonsterType = .blurBeast
    var classification: MonsterClassification? = nil
    var thumbnail: UIImage?

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.id == rhs.id }

    var longEdge: Int { max(pixelWidth, pixelHeight) }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
    }

    var formattedDuration: String {
        guard durationSeconds > 0 else { return "" }
        let total = Int(durationSeconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    var ageDescription: String {
        guard let date = creationDate else { return "Unknown era" }
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        if years >= 1 { return "\(years) yr ago" }
        let months = Calendar.current.dateComponents([.month], from: date, to: Date()).month ?? 0
        if months >= 1 { return "\(months) mo ago" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days <= 0 ? "Today" : "\(days) d ago"
    }

    var voiceOverDescription: String {
        switch kind {
        case .photo:
            return "\(monsterType.displayName), photo from \(ageDescription), \(formattedSize)."
        case .video:
            return "\(monsterType.displayName), video, \(formattedDuration), \(formattedSize), from \(ageDescription)."
        }
    }
}
