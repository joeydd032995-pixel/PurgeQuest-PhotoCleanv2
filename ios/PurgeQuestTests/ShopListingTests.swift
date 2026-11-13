//
//  ShopListingTests.swift
//  PurgeQuestTests
//
//  The Armory does not sell helms, chest pieces, legs or hands in 1.0: the hero sprite draws only held
//  gear, so a bought armor piece would never appear on the hero. These tests pin which slots are hidden
//  and that nothing a purchase unlocks is among them.
//

import Testing
import Foundation
@testable import PurgeQuest

struct ShopListingTests {

    @Test func armorSlotsAreHiddenFromTheShop() {
        #expect(CosmeticType.hiddenFromShop == [.head, .armor, .legs, .hands])
        for type in CosmeticType.hiddenFromShop {
            #expect(!type.isSoldInShop)
        }
    }

    @Test func theSameSlotsAreHiddenOnTheHero() {
        #expect(CosmeticType.hiddenFromHero == CosmeticType.hiddenFromShop)
        #expect(CosmeticType.weapon.isShownOnHero)
        #expect(CosmeticType.shield.isShownOnHero)
        #expect(!CosmeticType.head.isShownOnHero)
        #expect(!CosmeticType.armor.isShownOnHero)
    }

    @Test func everythingElseIsStillSold() {
        for type in CosmeticType.allCases where !CosmeticType.hiddenFromShop.contains(type) {
            #expect(type.isSoldInShop, "\(type) should stay in the shop")
        }
    }

    @Test func noPurchaseUnlocksAHiddenItem() {
        let hiddenPrefixes = ["head.", "armor.", "legs.", "hands."]
        for product in StoreKitService.ProductID.allCases {
            for id in product.unlocksCosmeticIDs {
                #expect(!hiddenPrefixes.contains { id.hasPrefix($0) }, "\(product) unlocks hidden item \(id)")
            }
        }
    }
}
