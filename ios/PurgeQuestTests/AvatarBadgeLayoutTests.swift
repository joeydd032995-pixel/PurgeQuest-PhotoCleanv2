//
//  AvatarBadgeLayoutTests.swift
//  PurgeQuestTests
//
//  The equipment tags around the hero. Head, armor, legs and hands are hidden in 1.0, so they have none. Armor, Shield, Legs and Hands used to have no tag at all, so
//  an equipped chestplate or shield showed nowhere on the Hero tab. Every worn slot now has one, and
//  the layout is checked for overlap at every size the avatar is drawn at.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct AvatarBadgeLayoutTests {

    @Test func everyWornSlotHasExactlyOneTag() {
        let worn = Set(CosmeticType.allCases).subtracting([.upgrade]).subtracting(CosmeticType.hiddenFromHero)
        #expect(Set(AvatarBadgeLayout.taggedTypes) == worn)
        #expect(AvatarBadgeLayout.taggedTypes.count == worn.count, "a slot is listed twice")
    }

    @Test(arguments: [150.0, 190.0, 210.0, 230.0, 280.0])
    func noTwoTagsOverlapAtAnyAvatarSize(size: Double) {
        let slots = AvatarBadgeLayout.slots
        let gap = AvatarBadgeLayout.tagSide + 4
        for (index, a) in slots.enumerated() {
            for b in slots[(index + 1)...] {
                // Two square tags overlap only when they are closer than one side on both axes.
                let dx = abs(a.x - b.x) * size
                let dy = abs(a.y - b.y) * size
                #expect(dx >= gap || dy >= gap, "\(a.type) and \(b.type) overlap at size \(size)")
            }
        }
    }

    @Test(arguments: [150.0, 210.0, 280.0])
    func tagsStayInsideTheAvatarFrame(size: Double) {
        // CharacterAvatarView's frame is (size + 120) wide and (size + 100) tall, centered on the backdrop.
        let halfWidth = (size + 120) / 2
        let halfHeight = (size + 100) / 2
        let half = AvatarBadgeLayout.tagSide / 2
        for slot in AvatarBadgeLayout.slots {
            #expect(abs(slot.x * size) + half <= halfWidth, "\(slot.type) leaves the frame sideways at size \(size)")
            #expect(abs(slot.y * size) + half <= halfHeight, "\(slot.type) leaves the frame vertically at size \(size)")
        }
    }

    @Test func theShieldTagIsOnTheShieldSideAndTheWeaponTagOnTheSwordSide() throws {
        // The sprite holds the sword in the hand on the right of the screen and the shield on the left.
        let shield = try #require(AvatarBadgeLayout.slots.first { $0.type == .shield })
        let weapon = try #require(AvatarBadgeLayout.slots.first { $0.type == .weapon })
        #expect(shield.x < 0)
        #expect(weapon.x > 0)
    }
}
