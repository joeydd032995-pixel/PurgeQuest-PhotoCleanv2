//
//  SeasonalCatalog.swift
//  PurgeQuest
//
//  Which cosmetics belong to which seasonal event, and when they may be bought. The catalog seeds
//  every seasonal item all year so that one a player owns never disappears; the rules here decide
//  whether a player who does not own it yet can buy it today.
//

import Foundation

enum SeasonalCatalog {

    /// The event that owns this cosmetic, if it is a seasonal exclusive.
    static func event(owning cosmeticID: String) -> SeasonalEvent? {
        SeasonalEventService.allEvents.first { $0.exclusiveCosmeticIDs.contains(cosmeticID) }
    }

    /// True when the cosmetic can be bought now: it is not a seasonal exclusive, or its event is live.
    static func isPurchasable(_ cosmeticID: String, activeEventID: String?) -> Bool {
        guard let owner = event(owning: cosmeticID) else { return true }
        return owner.id == activeEventID
    }
}
