//
//  DuplicateGroupBuilderTests.swift
//  PurgeQuestTests
//
//  Every copy in a duplicate group is booked as the monster the group card shows.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct DuplicateGroupBuilderTests {

    private static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func photo(_ id: String, bytes: Int64, screenshot: Bool = false, favorite: Bool = false) -> MediaItem {
        MediaItem(
            id: id, kind: .photo, creationDate: Self.epoch, pixelWidth: 4000, pixelHeight: 3000,
            durationSeconds: 0, estimatedBytes: bytes, isFavorite: favorite, playbackStyle: 1,
            isScreenshot: screenshot, sharpness: 60, luminance: 0.5
        )
    }

    private func print(_ item: MediaItem, content: String?) -> MediaFingerprint {
        MediaFingerprint(
            assetID: item.id, byteSize: item.estimatedBytes, pixelWidth: item.pixelWidth,
            pixelHeight: item.pixelHeight, durationSeconds: 0, creationDate: item.creationDate,
            isFavorite: item.isFavorite, isScreenshot: item.isScreenshot, hasEdits: false,
            isScreenRecording: false, dHash: nil, sharpness: item.sharpness, contentHash: content
        )
    }

    @Test func everyCopyOfAGroupTakesTheClustersMonster() throws {
        // Three identical files. Each starts as the Blur Beast the library builder gave it alone.
        let items = [photo("c0", bytes: 2_000_000), photo("c1", bytes: 2_000_001), photo("c2", bytes: 2_000_002)]
        #expect(items.allSatisfy { $0.monsterType == .blurBeast })
        let library = MonsterClassifier.classify(items: items, fingerprints: items.map { print($0, content: "same") })
        let clusterMonster = try #require(library.classifications["c0"]?.monsterType)
        #expect(clusterMonster.family == .duplicateDragons)

        let folded = DuplicateGroupBuilder.fold(items: items, library: library)
        let group = try #require(folded.groups["c0"])
        #expect(group.members.map(\.id) == ["c0", "c1", "c2"])
        #expect(group.members.allSatisfy { $0.monsterType == clusterMonster })
        #expect(folded.items.allSatisfy { $0.monsterType == clusterMonster })
        #expect(folded.items.allSatisfy { $0.classification?.monsterType == clusterMonster })
        #expect(folded.nonRepresentatives == ["c1", "c2"])
    }

    @Test func aLoneItemKeepsItsOwnVerdict() throws {
        let twins = [photo("t0", bytes: 3_000_000), photo("t1", bytes: 3_000_001)]
        let shot = photo("shot", bytes: 400_000, screenshot: true)
        let items = twins + [shot]
        let prints = twins.map { print($0, content: "same") } + [print(shot, content: nil)]
        let library = MonsterClassifier.classify(items: items, fingerprints: prints)
        let folded = DuplicateGroupBuilder.fold(items: items, library: library)

        let kept = try #require(folded.items.first { $0.id == "shot" })
        #expect(kept.monsterType == .screenshotSpecter)
        #expect(folded.groups.keys.sorted() == ["t0"])
        #expect(!folded.nonRepresentatives.contains("shot"))
    }

    @Test func theSuggestedKeeperRidesAlongWithoutBeingDecided() throws {
        let items = [photo("c0", bytes: 2_000_000), photo("c1", bytes: 2_000_001, favorite: true)]
        let library = MonsterClassifier.classify(items: items, fingerprints: items.map { print($0, content: "same") })
        let group = try #require(DuplicateGroupBuilder.fold(items: items, library: library).groups["c0"])
        #expect(group.survivorID == "c1")
    }

    @Test func aBatchWithoutDuplicatesIsJustClassified() {
        let items = [photo("a", bytes: 1_000_000), photo("b", bytes: 2_000_000)]
        let library = MonsterClassifier.classify(items: items, fingerprints: items.map { print($0, content: nil) })
        let folded = DuplicateGroupBuilder.fold(items: items, library: library)
        #expect(folded.groups.isEmpty)
        #expect(folded.nonRepresentatives.isEmpty)
        #expect(folded.items.count == 2)
    }
}
