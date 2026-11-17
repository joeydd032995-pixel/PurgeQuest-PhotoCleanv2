import Testing
import Foundation
@testable import PurgeQuest

@Suite struct ShopPricingTests {

    @Test func aPriceIsTheBaseTimesTwoAndAHalfToTheNearestTen() {
        #expect(ShopPricing.price(base: 200) == 500)
        #expect(ShopPricing.price(base: 150) == 380)    // 375 rounds up to 380
        #expect(ShopPricing.price(base: 220) == 550)
        #expect(ShopPricing.price(base: 250) == 630)    // 625 rounds up
        #expect(ShopPricing.price(base: 350) == 880)    // 875 rounds up
        #expect(ShopPricing.price(base: 650) == 1630)
        #expect(ShopPricing.price(base: 3000) == 7500)
    }

    @Test func aFreeItemStaysFree() {
        #expect(ShopPricing.price(base: 0) == 0)
        #expect(ShopPricing.price(base: -5) == 0)
    }

    @Test func everyPaidPriceLandsBetweenTwoAndTwoThirdsAndTwoAndThreeQuarterTimesItsBase() {
        // The owner's band: 2.25x to 2.75x. Checked for every base the catalog could plausibly hold.
        for base in stride(from: 100, through: 20_000, by: 10) {
            let price = ShopPricing.price(base: base)
            #expect(price * 100 >= base * ShopPricing.lowestHundredths, "base \(base) → \(price) is under 2.25x")
            #expect(price * 100 <= base * ShopPricing.highestHundredths, "base \(base) → \(price) is over 2.75x")
        }
    }

    @Test func aPriceIsWholeTensAndNeverFallsAsTheBaseRises() {
        var last = 0
        for base in 1...5_000 {
            let price = ShopPricing.price(base: base)
            #expect(price % 10 == 0)
            #expect(price >= last)
            last = price
        }
    }

    @Test func theGearTiersStayWhereTheyWereAfterThePricesRise() {
        // Tiers were set at base prices of 250, 500, 750 and 900. A piece priced from those bases keeps its tier.
        func tier(base: Int) -> GearTier {
            HeroAppearance.gearTier(maxEquippedPrice: ShopPricing.price(base: base), hasPremium: false)
        }
        #expect(tier(base: 240) == .standard)
        #expect(tier(base: 250) == .seasoned)
        #expect(tier(base: 490) == .seasoned)
        #expect(tier(base: 500) == .elite)
        #expect(tier(base: 750) == .legendary)
        #expect(tier(base: 900) == .mythic)
        #expect(tier(base: 3000) == .mythic)
    }
}
