//
//  ClusterReasonTests.swift
//  PurgeQuestTests
//
//  A duplicate group explains itself: the Album Echo says it was saved again on another day.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ClusterReasonTests {

    private func copies(daysApart: Double, exactContent: Bool = false) -> (items: [MediaItem], prints: [MediaFingerprint]) {
        let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var items: [MediaItem] = []
        var prints: [MediaFingerprint] = []
        for i in 0..<2 {
            let date = epoch.addingTimeInterval(Double(i) * daysApart * 86_400)
            let size = Int64(5_000_000 + i * 100)
            let item = MediaItem(
                id: "copy\(i)", kind: .photo, creationDate: date, pixelWidth: 4000, pixelHeight: 3000,
                durationSeconds: 0, estimatedBytes: size, isFavorite: false, playbackStyle: 1
            )
            items.append(item)
            prints.append(MediaFingerprint(
                assetID: item.id, byteSize: size, pixelWidth: 4000, pixelHeight: 3000, durationSeconds: 0,
                creationDate: date, isFavorite: false, isScreenshot: false, hasEdits: false,
                isScreenRecording: false, dHash: 0x0F0F_0F0F_0F0F_0F0F, sharpness: nil,
                contentHash: exactContent ? "same" : nil
            ))
        }
        return (items, prints)
    }

    @Test func anEchoAcrossWeeksSaysItWasSavedAgain() {
        let echo = copies(daysApart: 55)
        let verdict = MonsterClassifier.classify(items: echo.items, fingerprints: echo.prints).classifications["copy0"]
        #expect(verdict?.monsterType == .albumEcho)
        #expect(verdict?.reasons == [.nearDuplicateCluster, .repeatedCapture])
        #expect(verdict?.whyText.contains("Saved more than once on different days") == true)
    }

    @Test func otherDuplicatesDoNotClaimToBeRepeatedCaptures() {
        let pair = copies(daysApart: 0.04, exactContent: true)
        let verdict = MonsterClassifier.classify(items: pair.items, fingerprints: pair.prints).classifications["copy0"]
        #expect(verdict?.reasons == [.exactBinaryMatch])
    }
}
