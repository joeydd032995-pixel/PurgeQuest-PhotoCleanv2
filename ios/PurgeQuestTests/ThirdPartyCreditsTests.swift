//
//  ThirdPartyCreditsTests.swift
//  PurgeQuestTests
//
//  The list behind the Credits screen in Settings: the art and the typeface other people made, who made
//  them, and where the app uses each. Pure Foundation, so these also run on the Linux harness
//  (tools/swift_harness/run.sh): nothing here may touch UIKit or SwiftUI. That the Cinzel license text
//  ships inside the app is CreditsAssetTests, which needs the app bundle and so runs under Xcode only.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ThirdPartyCreditsTests {

    @Test func everyCreditSaysWhatItIsUsedForWhatItIsAndWhoMadeIt() {
        for credit in ThirdPartyCredits.all {
            #expect(!credit.usedFor.trimmingCharacters(in: .whitespaces).isEmpty, "a credit has no use")
            #expect(!credit.name.trimmingCharacters(in: .whitespaces).isEmpty, "\(credit.usedFor) has no pack name")
            #expect(!credit.author.trimmingCharacters(in: .whitespaces).isEmpty, "\(credit.usedFor) has no author")
        }
    }

    @Test func creditsCanBeListedBecauseTheirIDsAreUnique() {
        let ids = ThirdPartyCredits.all.map(\.id)
        #expect(Set(ids).count == ids.count, "two credits share an id: \(ids)")
    }

    @Test func theArtIsCreditedToItsThreeSources() {
        let authors = ThirdPartyCredits.art.map(\.author).joined(separator: " | ")
        #expect(authors.contains("CraftPix"))
        #expect(authors.contains("Mica"))
        #expect(authors.contains("LumioLab"))
    }

    @Test func cinzelIsCreditedWithItsAuthorAndItsLicense() {
        let font = ThirdPartyCredits.font
        #expect(font.name == "Cinzel")
        #expect(font.author.contains("Natanael Gama"))
        #expect(ThirdPartyCredits.fontLicenseName == "SIL Open Font License, Version 1.1")
        #expect(ThirdPartyCredits.fontLicenseAssetName == "Cinzel-OFL")
    }

    @Test func theTypefaceComesLastAndTheArtDoesNotRepeatIt() {
        #expect(ThirdPartyCredits.all.last == ThirdPartyCredits.font)
        #expect(!ThirdPartyCredits.art.contains(ThirdPartyCredits.font))
    }
}
