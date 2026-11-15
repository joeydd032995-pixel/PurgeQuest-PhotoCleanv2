//
//  StorageQuestTests.swift
//  PurgeQuestTests
//
//  The storage quest adds up a confirmed room's total size once, in the megabytes Photos shows (owner
//  decision, 15 November 2026), so a room of small files counts: 600 screenshots of 470 KB used to add 0,
//  each file being rounded on its own. The rounding itself is `QuestProgress` (tested in QuestRulesTests, in
//  the Linux harness); these tests cover how it is booked onto a quest. They need the app target
//  (GameDataService, Quest), so they run in Xcode and CI only.
//

import Testing
@testable import PurgeQuest

@MainActor
struct StorageQuestTests {

    private func storageQuest(target: Int = 500) -> Quest {
        Quest(title: "Storage Liberation", subtitle: "", kind: .mbFreed, monsterType: nil,
              targetCount: target, rewardXP: 1, rewardGems: 1)
    }

    @Test func aRoomOfSmallFilesAddsUp() {
        let quest = storageQuest()
        GameDataService.addStorageProgress([quest], bytes: 600 * 470_000)
        #expect(quest.currentCount == 282)
        #expect(!quest.completed)
    }

    @Test func progressBuildsAcrossRoomsAndStopsAtTheTarget() {
        let quest = storageQuest()
        GameDataService.addStorageProgress([quest], bytes: 282_000_000)
        GameDataService.addStorageProgress([quest], bytes: 300_000_000)
        #expect(quest.currentCount == 500)
        #expect(quest.completed)
        GameDataService.addStorageProgress([quest], bytes: 50_000_000)
        #expect(quest.currentCount == 500)
    }

    @Test func oneHalfGigabyteVideoIsExactlyTheTarget() {
        let quest = storageQuest()
        GameDataService.addStorageProgress([quest], bytes: 500_000_000)
        #expect(quest.currentCount == 500)
        #expect(quest.completed)
    }

    @Test func deletingOneItemNoLongerTouchesAStorageQuest() {
        let quest = storageQuest()
        GameDataService.updateQuests([quest], for: .blurBeast)
        GameDataService.updateQuests([quest], for: .memoryHogMinotaur)
        #expect(quest.currentCount == 0)
    }

    @Test func otherQuestsAreLeftAloneByStorageProgress() {
        let kills = Quest(title: "Blur Beast Hunter", subtitle: "", kind: .photoSlay, monsterType: .blurBeast,
                          targetCount: 8, rewardXP: 1, rewardGems: 1)
        let anything = Quest(title: "Dungeon Clear", subtitle: "", kind: .anySlay, monsterType: nil,
                             targetCount: 25, rewardXP: 1, rewardGems: 1)
        GameDataService.addStorageProgress([kills, anything], bytes: 900_000_000)
        #expect(kills.currentCount == 0)
        #expect(anything.currentCount == 0)
    }

    @Test func aRoomWithNothingOfSizeAddsNothing() {
        let quest = storageQuest()
        GameDataService.addStorageProgress([quest], bytes: 0)
        GameDataService.addStorageProgress([quest], bytes: 400_000)   // under half a megabyte in total
        #expect(quest.currentCount == 0)
    }

    @Test func aFinishedQuestStaysAsItWas() {
        let quest = storageQuest()
        quest.currentCount = 500
        quest.completed = true
        GameDataService.addStorageProgress([quest], bytes: 100_000_000)
        #expect(quest.currentCount == 500)
    }
}
