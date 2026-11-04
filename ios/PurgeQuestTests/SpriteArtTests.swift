//
//  SpriteArtTests.swift
//  PurgeQuestTests
//
//  The sprite sheets added for the Wraith monsters, the Forest Spirit and
//  Phantom Purge pets, and the event decor: every sheet is in the asset
//  catalog at the size its frames promise, the frame clock is safe, and the
//  pets and event reference only items and art that exist.
//

import Testing
import SwiftData
import SwiftUI
import UIKit
@testable import PurgeQuest

struct SpriteArtTests {

    @Test func everySheetIsInTheAssetCatalogWithWholeFrames() throws {
        for sheet in SpriteArt.all {
            let image = try #require(UIImage(named: sheet.asset), "missing asset \(sheet.asset)")
            let cg = try #require(image.cgImage)
            #expect(cg.width == Int(sheet.cellWidth) * sheet.frames, "\(sheet.asset) width does not match its frames")
            #expect(cg.height == Int(sheet.cellHeight), "\(sheet.asset) height does not match its cell")
        }
        #expect(Set(SpriteArt.all.map(\.asset)).count == SpriteArt.all.count)
    }

    @Test func frameClockStaysInRangeAndHandlesStillSheets() {
        let sheet = SpriteArt.mistWraith
        for offset in stride(from: 0.0, through: 5.0, by: 0.13) {
            let index = sheet.frameIndex(at: Date(timeIntervalSinceReferenceDate: offset))
            #expect((0..<sheet.frames).contains(index))
        }
        #expect(SpriteArt.gravestone.frameIndex(at: Date()) == 0)
        // Dates before the reference date give negative ticks; they must still land in range.
        let early = sheet.frameIndex(at: Date(timeIntervalSinceReferenceDate: -3.37))
        #expect((0..<sheet.frames).contains(early))
    }

    @Test func eachWraithHasItsSheet() {
        #expect(SpriteArt.monsterSheet(for: .mistWraith) == SpriteArt.mistWraith)
        #expect(SpriteArt.monsterSheet(for: .tatterWraith) == SpriteArt.tatterWraith)
        #expect(SpriteArt.monsterSheet(for: .voidWraith) == SpriteArt.voidWraith)
        #expect(SpriteArt.monsterSheet(for: .blurBeast) == nil)
    }

    @Test @MainActor func spritePetsAreInTheCatalogAsPets() throws {
        let ids = ["pet.spiritBlue", "pet.spiritGreen", "pet.spiritRed", "pet.spiritYellow", "pet.ghost", "pet.bat"]
        let container = try ModelContainer(for: CosmeticItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        GameDataService.seedCosmeticsIfNeeded(in: context)
        let seeds = try context.fetch(FetchDescriptor<CosmeticItem>())
        for id in ids {
            #expect(SpriteArt.petSheet(id: id) != nil, "no sprite for \(id)")
            let item = seeds.first { $0.id == id }
            #expect(item != nil, "\(id) is not in the seeded catalog")
            #expect(item?.type == .pet)
        }
        #expect(SpriteArt.petSheet(id: "pet.owl") == nil)
    }

    @Test @MainActor func phantomPurgeOffersItsPetsAndShowsDecor() throws {
        let halloween = try #require(SeasonalEventService.allEvents.first { $0.id == "halloween" })
        #expect(halloween.exclusiveCosmeticIDs.contains("pet.ghost"))
        #expect(halloween.exclusiveCosmeticIDs.contains("pet.bat"))
        #expect(!halloween.decor.isEmpty)
        #expect(halloween.bonusMonsters.contains(.voidWraith))
        for event in SeasonalEventService.allEvents where event.id != "halloween" {
            #expect(event.decor.isEmpty)
        }
    }
}
