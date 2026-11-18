//
//  ShopPricing.swift
//  PurgeQuest
//
//  What the shop charges. Every item in the catalog carries a base price, and the price a player pays is that
//  base times 2.5, rounded to the nearest 10 gems, so every paid item costs between 2.25 and 2.75 times its
//  base. A free item stays free. Changing the economy again is a change to `multiplierTenths` here, not to the
//  catalog. Foundation only, so the Linux harness checks it.
//

import Foundation

nonisolated enum ShopPricing {

    /// The multiplier over the catalog's base prices, in tenths: 25 is ×2.5.
    static let multiplierTenths = 25

    /// The lowest and highest multiplier a price may land on, in hundredths (×2.25 and ×2.75).
    static let lowestHundredths = 225
    static let highestHundredths = 275

    /// The price a player pays for an item whose base price is `base`: the base times 2.5 to the nearest 10
    /// gems, halves rounding up. Zero stays zero.
    static func price(base: Int) -> Int {
        guard base > 0 else { return 0 }
        // base * 2.5 / 10 = base / 4 (when the multiplier is 25 tenths), rounded half up, then times 10.
        let tens = (base * multiplierTenths + 50) / 100
        return tens * 10
    }
}
