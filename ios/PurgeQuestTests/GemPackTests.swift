//
//  GemPackTests.swift
//  PurgeQuestTests
//
//  The real-money gem packs (owner, 20 November 2026): 500, 1,250, 2,000, 4,500 and 10,000 gems. They are
//  consumable; the three cosmetic unlocks are not and grant no gems. StoreKitService is main-actor code, so
//  these run in Xcode and CI only. The repo guard separately checks that these ids match Configuration.storekit.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct GemPackTests {

    private typealias ProductID = StoreKitService.ProductID

    @Test func theGemPacksAre500_1250_2000_4500And10000() {
        let packs = ProductID.allCases.filter(\.isConsumable)
        #expect(packs.map(\.gemAmount) == [500, 1250, 2000, 4500, 10000])
        #expect(packs.map(\.rawValue) == [
            "com.purgequest.gems.500", "com.purgequest.gems.1250", "com.purgequest.gems.2000",
            "com.purgequest.gems.4500", "com.purgequest.gems.10000"
        ])
    }

    @Test func eachPacksIdNamesItsGemCount() {
        for pack in ProductID.allCases where pack.isConsumable {
            #expect(pack.rawValue.hasSuffix(".\(pack.gemAmount)"), "\(pack.rawValue) grants \(pack.gemAmount)")
        }
    }

    @Test func theCosmeticUnlocksAreNotConsumableAndGrantNoGems() {
        let cosmetics = ProductID.allCases.filter { !$0.isConsumable }
        #expect(cosmetics.count == 3)
        #expect(cosmetics.allSatisfy { $0.gemAmount == 0 && !$0.unlocksCosmeticIDs.isEmpty })
    }

    @Test func thePacksGrowInSizeAndNoTwoGrantTheSameGems() {
        // Declared smallest to largest, so the shop lists them in order.
        let amounts = ProductID.allCases.filter(\.isConsumable).map(\.gemAmount)
        #expect(amounts == amounts.sorted())
        #expect(Set(amounts).count == amounts.count, "no two packs grant the same gems")
    }
}
