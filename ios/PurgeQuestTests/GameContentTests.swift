//
//  GameContentTests.swift
//  PurgeQuestTests
//
//  The content that names monsters (GameContent.swift): a seasonal bonus counts the same monsters a
//  quest does, and the daily pool is well formed.
//
//  Foundation only, so this runs in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct GameContentTests {

    // MARK: - Seasonal bonuses count what quests count

    @Test func aBonusForTheDuplicateDragonPaysForTheWholeFamily() {
        let newYear = SeasonalBonusCatalog.newYear
        #expect(newYear.monsters.contains(.duplicateDragon))
        for monster in MonsterType.allCases where monster.family == .duplicateDragons {
            #expect(newYear.applies(to: monster), "\(monster) is a duplicate and earns no New Year bonus")
            #expect(newYear.multiplier(for: monster) == newYear.multiplier)
        }
        #expect(newYear.applies(to: .ancientArchive))
        #expect(!newYear.applies(to: .blurBeast))
        #expect(newYear.multiplier(for: .blurBeast) == 1)
    }

    @Test func everyOtherBonusPaysExactlyTheMonstersItLists() {
        for (event, bonus) in SeasonalBonusCatalog.byEventID where !bonus.monsters.contains(.duplicateDragon) {
            for monster in MonsterType.allCases {
                #expect(bonus.applies(to: monster) == bonus.monsters.contains(monster), "\(event): \(monster)")
            }
        }
    }

    @Test func aBonusAndAQuestAgreeOnWhatCounts() {
        // The same rule decides both, so a player is never paid by one and not the other.
        for quest in QuestCatalog.daily {
            guard let target = quest.monsterType else { continue }
            let bonus = SeasonalBonus(monsters: [target], multiplier: 2)
            for monster in MonsterType.allCases {
                #expect(bonus.applies(to: monster) == monster.counts(as: target), "\(quest.title): \(monster)")
            }
        }
    }

    // MARK: - The daily pool

    @Test func everyDailyQuestCanBeFinishedAndPaysSomething() {
        let pool = QuestCatalog.daily
        // The daily draw picks four distinct quests.
        #expect(pool.count >= 4)
        #expect(Set(pool.map(\.title)).count == pool.count, "two quests share a title")
        for quest in pool {
            #expect(quest.targetCount > 0, "\(quest.title) has nothing to do")
            #expect(quest.rewardXP > 0 && quest.rewardGems > 0, "\(quest.title) pays nothing")
            #expect(!quest.subtitle.isEmpty)
        }
    }
}
