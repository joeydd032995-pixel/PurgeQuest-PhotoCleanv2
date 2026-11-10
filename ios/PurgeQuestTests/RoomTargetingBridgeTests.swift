//
//  RoomTargetingBridgeTests.swift
//  PurgeQuestTests
//
//  RoomTargeting is pure and tested in RoomTargetingTests. These pin its links to the app: the
//  thresholds restate MonsterClassifier's, a MediaItem is read into the facts the rules use, and a
//  bucket means what the classifier already calls the same thing.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct RoomTargetingBridgeTests {

    private func item(
        kind: MediaKind = .photo, bytes: Int64 = 3_000_000, duration: Double = 0,
        taken: Date? = nil, screenshot: Bool = false, sharpness: Double? = nil
    ) -> MediaItem {
        MediaItem(
            id: "item", kind: kind, creationDate: taken, pixelWidth: 4032, pixelHeight: 3024,
            durationSeconds: duration, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenshot: screenshot, isScreenRecording: false, isLivePhoto: false,
            isLooping: false, sharpness: sharpness, luminance: 0.5
        )
    }

    private func buckets(_ item: MediaItem, now: Date) -> Set<RoomBucket> {
        RoomTargeting.buckets(for: RoomTargetFacts(item: item), now: now)
    }

    @Test func thresholdsRestateTheClassifier() {
        #expect(RoomTargeting.blurSharpness == MonsterClassifier.blurSharpness)
        #expect(RoomTargeting.oldPhotoYears == MonsterClassifier.archiveYears)
        #expect(RoomTargeting.largeVideoBytes == MonsterClassifier.hundredMegabyte)
    }

    @Test func aMediaItemIsReadIntoTheFactsTheRulesUse() {
        let taken = Date(timeIntervalSince1970: 1_000_000_000)
        let video = item(kind: .video, bytes: 250_000_000, duration: 130, taken: taken, sharpness: 4.5)
        let expected = RoomTargetFacts(
            isVideo: true, isScreenshot: false, sharpness: 4.5,
            durationSeconds: 130, estimatedBytes: 250_000_000, creationDate: taken
        )
        #expect(RoomTargetFacts(item: video) == expected)
        #expect(RoomTargetFacts(item: item(screenshot: true)).isScreenshot)
        #expect(!RoomTargetFacts(item: item(kind: .photo)).isVideo)
    }

    @Test func realItemsLandInTheBucketsTheDashboardPromises() {
        let now = Date()
        let fourYearsAgo = Calendar.current.date(byAdding: .year, value: -4, to: now)
        #expect(buckets(item(sharpness: 2), now: now) == [.blur])
        #expect(buckets(item(screenshot: true, sharpness: 2), now: now) == [.screenshots])
        #expect(buckets(item(kind: .video, bytes: 150_000_000, duration: 10), now: now) == [.largeVideo])
        #expect(buckets(item(kind: .video, bytes: 5_000_000, duration: 200), now: now) == [.largeVideo])
        #expect(buckets(item(taken: fourYearsAgo, sharpness: 60), now: now) == [.old])
        #expect(buckets(item(sharpness: 60), now: now).isEmpty)
    }

    @Test func aBucketMeansWhatTheClassifierAlreadyCallsTheSameThing() {
        let now = Date()
        let fourYearsAgo = Calendar.current.date(byAdding: .year, value: -4, to: now)
        let blurry = item(sharpness: 2)
        let shot = item(screenshot: true)
        let old = item(taken: fourYearsAgo, sharpness: 60)
        // Blur Beast is also the classifier's catch-all, so the monster alone proves nothing: check the reason.
        // The blurry photo is a Blur Beast because it saw blur; a sharp control is one because it saw nothing.
        #expect(MonsterClassifier.classifySolo(blurry, now: now).monsterType == .blurBeast)
        #expect(MonsterClassifier.classifySolo(blurry, now: now).reasons == [.outOfFocus])
        #expect(MonsterClassifier.classifySolo(item(sharpness: 60), now: now).reasons == [.noStrongSignal])
        #expect(MonsterClassifier.classifySolo(shot, now: now).monsterType == .screenshotSpecter)
        #expect(MonsterClassifier.classifySolo(old, now: now).monsterType == .ancientArchive)
    }
}
