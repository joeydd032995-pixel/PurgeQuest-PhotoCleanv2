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

    // MARK: - Plain words first

    /// The old quests said "Slay 8 blurry photo monsters" and "Vanquish 5 Duplicate Dragons": a first-time
    /// player cannot tell what to do. A quest now starts with what to do, in plain words.
    @Test func everyQuestStartsWithAPlainVerb() {
        let loreWords = ["slay", "slain", "vanquish", "banish", "defeat", "monsters"]
        for quest in QuestCatalog.daily {
            #expect(quest.subtitle.hasPrefix("Delete ") || quest.subtitle.hasPrefix("Move "),
                    "\(quest.title) starts with \"\(quest.subtitle)\"")
            let words = quest.subtitle.lowercased()
            for word in loreWords {
                #expect(!words.contains(word), "\(quest.title) still says \"\(word)\"")
            }
        }
    }

    /// A quest counts the monster the card shows, so it names that monster (the chip on the card is the
    /// handle a player matches) and says in plain words what the monster is. The Duplicate Dragon quest
    /// counts a whole family (`MonsterType.counts(as:)`), so it says duplicates instead.
    @Test func aMonsterQuestNamesTheMonsterTheCardWillShow() {
        for quest in QuestCatalog.daily {
            guard let monster = quest.monsterType else { continue }
            if monster == .duplicateDragon {
                #expect(quest.subtitle.lowercased().contains("duplicate"), "\(quest.title) never says duplicates")
            } else {
                #expect(quest.subtitle.contains(monster.displayName), "\(quest.title) never names \(monster.displayName)")
            }
        }
    }

    @Test func aQuestSubtitleStatesItsOwnTarget() {
        for quest in QuestCatalog.daily {
            #expect(quest.subtitle.hasPrefix("Delete \(quest.targetCount) ") || quest.subtitle.hasPrefix("Move \(quest.targetCount) "),
                    "\(quest.title) says a different number than \(quest.targetCount)")
        }
    }

    /// The sizes a quest quotes are the classifier's own lines, not a rounding of them. (The two-minute
    /// line of the Leviathan is `duration > 120` inline in MonsterClassifier, so it has no constant to pin.)
    @Test func theSizesAQuestQuotesAreTheClassifiersOwn() throws {
        let minotaur = try #require(QuestCatalog.daily.first { $0.monsterType == .memoryHogMinotaur })
        #expect(minotaur.subtitle.contains("\(MonsterClassifier.halfGigabyte / 1_000_000) MB"))
        let vampire = try #require(QuestCatalog.daily.first { $0.monsterType == .videoVampire })
        #expect(vampire.subtitle.contains("\(MonsterClassifier.hundredMegabyte / 1_000_000) MB"))
    }
}
