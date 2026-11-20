import Testing
import Foundation
@testable import PurgeQuest

/// The gem economy as a whole (17 November 2026): a photo pays 2 gems and a video 3, shop prices are 2.5 times
/// their base, and every other gem amount is sized against those two facts. Foundation only, so the Linux
/// harness runs it; EconomyTests (Xcode and CI) covers the parts that need SwiftData.
@Suite struct EconomyBalanceTests {

    // MARK: Bonuses follow the flat award

    @Test func theDiveBonusesArePhotosWorthOfGems() {
        #expect(DiveRules.perfectRoomBonusGems == 5 * DiveRules.gemsPerPhoto)
        #expect(DiveRules.perfectRoomBonusGems == 10)
        #expect(DiveRules.fullDiveBonusGemsPerRoom == 4 * DiveRules.gemsPerPhoto)
        #expect(DiveRules.fullDiveBonusGemsPerRoom == 8)
    }

    @Test func aFullDivesBonusesAreAboutHalfWhatItsDeletionsPaySameAsBefore() {
        // Five rooms of 20 photos, every room perfect. It was 125 of 270 (46%) when a photo paid about 2.7 gems.
        let deletions = 5 * 20 * DiveRules.gemsPerPhoto
        let bonuses = 5 * DiveRules.perfectRoomBonusGems + 5 * DiveRules.fullDiveBonusGemsPerRoom
        #expect(deletions == 200)
        #expect(bonuses == 90)
        #expect(Double(bonuses) / Double(deletions) <= 0.5, "the bonuses are a bonus, not the main income")
        #expect(Double(bonuses) / Double(deletions) >= 0.4)
    }

    @Test func theRallyCostsItsOldPriceTimesTheShopsMultiplier() {
        #expect(DiveRules.rallyCostGems == 250)
        #expect(DiveRules.rallyCostGems * 100 >= 100 * ShopPricing.lowestHundredths)
        #expect(DiveRules.rallyCostGems * 100 <= 100 * ShopPricing.highestHundredths)
    }

    // MARK: Quests are sized against the deletions they ask for

    /// The gems the deletions a quest asks for already pay: photos at 2, videos at 3, any item at the photo rate.
    private func deletionGems(of quest: QuestTemplate) -> Int {
        switch quest.kind {
        case .videoSlay: return quest.targetCount * DiveRules.gemsPerVideo
        default:         return quest.targetCount * DiveRules.gemsPerPhoto
        }
    }

    @Test func everyCountedQuestPaysOneAndAHalfToThreeAndAHalfTimesItsDeletions() {
        for quest in QuestCatalog.daily where quest.kind != .mbFreed {
            let base = deletionGems(of: quest)
            #expect(quest.rewardGems * 2 >= base * 3, "\(quest.title): \(quest.rewardGems) is under 1.5x of \(base)")
            #expect(quest.rewardGems * 2 <= base * 7, "\(quest.title): \(quest.rewardGems) is over 3.5x of \(base)")
        }
    }

    @Test func everyQuestRewardIsAWholeFive() {
        for quest in QuestCatalog.daily {
            #expect(quest.rewardGems % 5 == 0, "\(quest.title) pays \(quest.rewardGems)")
        }
    }

    @Test func theQuestsPayWhatTheTableInTheCatalogSays() {
        let gems = Dictionary(uniqueKeysWithValues: QuestCatalog.daily.map { ($0.title, $0.rewardGems) })
        #expect(gems["Blur Beast Hunter"] == 25)
        #expect(gems["Duplicate Dragon Slayer"] == 25)
        #expect(gems["Video Vampire Purge"] == 40)
        #expect(gems["LongTake Leviathan"] == 25)
        #expect(gems["Dungeon Clear"] == 75)
        #expect(gems["Memory Hog Hunter"] == 20)
        #expect(gems["Storage Liberation"] == 100)
    }

    @Test func aQuestIsNeverWorthMoreThanFiftyPhotos() {
        // The storage quest is the largest; at 2 gems a photo, 100 gems is 50 photos. Before the flat award the
        // same quest's 140 gems were 70 photos or more.
        let top = QuestCatalog.daily.map(\.rewardGems).max() ?? 0
        #expect(top / DiveRules.gemsPerPhoto <= 50)
    }
}
