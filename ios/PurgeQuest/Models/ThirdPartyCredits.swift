//
//  ThirdPartyCredits.swift
//  PurgeQuest
//
//  What the Credits screen in Settings lists: the art and the typeface that other people made, who made
//  them, and where the app uses each. docs/CREDITS.md is the full record (terms, links, how the files
//  were prepared); when a pack is added or dropped, change both. The Cinzel license text is not here: it
//  ships as a data asset (`fontLicenseAssetName`) that tools/ci/repo_guard.py keeps identical to
//  docs/licenses/cinzel-OFL.txt.
//
//  Pure Foundation (no SwiftUI), so the Linux harness runs it.
//

import Foundation

/// One line on the Credits screen.
nonisolated struct ThirdPartyCredit: Identifiable, Hashable, Sendable {
    /// What the app uses it for, such as "Wraith monsters". Each credit has its own, so it is the id.
    let usedFor: String
    /// The pack or the typeface, as its maker names it.
    let name: String
    /// Who made it and where it came from.
    let author: String

    var id: String { usedFor }
}

nonisolated enum ThirdPartyCredits {
    /// The art packs, in the order the screen shows them.
    static let art: [ThirdPartyCredit] = [
        ThirdPartyCredit(
            usedFor: "Hero characters",
            name: "Free Chibi Valkyrie, Necromancer of the Shadow, Seer, Forest Ranger, Dark Oracle, "
                + "Bloody Alchemist, Skeleton Crusader and Skeleton Warrior Character Sprites, "
                + "and Free Golem Chibi 2D Game Sprites",
            author: "CraftPix (craftpix.net)"),
        ThirdPartyCredit(
            usedFor: "Staves and shields",
            name: "Free Staves 2D Weapon Pack and Free Shield 2D Game Assets Pack",
            author: "CraftPix (craftpix.net)"),
        ThirdPartyCredit(
            usedFor: "Wraith monsters",
            name: "Free Wraith Tiny Style 2D Sprites",
            author: "CraftPix (craftpix.net)"),
        ThirdPartyCredit(
            usedFor: "Forest Spirit pets",
            name: "Cute Forest Spirit - Sprite Pack",
            author: "Mica (itch.io)"),
        ThirdPartyCredit(
            usedFor: "Phantom Purge event art",
            name: "Halloween Props & FX, free sampler",
            author: "LumioLab (itch.io)"),
    ]

    /// The typeface for titles and headings. Its license asks that the notice and the license text travel
    /// with the font, so the Credits screen shows both.
    static let font = ThirdPartyCredit(
        usedFor: "Titles and headings",
        name: "Cinzel",
        author: "Natanael Gama and The Cinzel Project Authors")

    /// The license Cinzel comes under, and the data asset (in Assets.xcassets) that holds its full text.
    static let fontLicenseName = "SIL Open Font License, Version 1.1"
    static let fontLicenseAssetName = "Cinzel-OFL"

    /// Every credit on the screen: the art first, then the typeface.
    static var all: [ThirdPartyCredit] { art + [font] }
}
