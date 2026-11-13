//
//  CreditsAssetTests.swift
//  PurgeQuestTests
//
//  The part of the Credits screen that needs the app bundle, so it runs under Xcode only (it is not in
//  the Linux harness): Cinzel's license text ships inside the app, as a data asset the same way the font
//  files do. The list on the screen is ThirdPartyCreditsTests.
//

import Testing
import UIKit
@testable import PurgeQuest

@MainActor
struct CreditsAssetTests {

    @Test func theCinzelLicenseTextShipsInsideTheApp() throws {
        let asset = try #require(NSDataAsset(name: ThirdPartyCredits.fontLicenseAssetName),
                                 "the \(ThirdPartyCredits.fontLicenseAssetName) data asset is missing")
        let text = String(decoding: asset.data, as: UTF8.self)
        #expect(text.contains("SIL OPEN FONT LICENSE Version 1.1"))
        #expect(text.contains("Copyright 2020 The Cinzel Project Authors"))
        #expect(text.contains("Natanael Gama"))
    }
}
