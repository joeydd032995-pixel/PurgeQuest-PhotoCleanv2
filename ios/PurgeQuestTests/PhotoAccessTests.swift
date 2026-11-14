//
//  PhotoAccessTests.swift
//  PurgeQuestTests
//
//  What the app may say about the photo library, state by state. The rule these guard: without
//  access, no screen reports the library as clean. Pure Foundation, so these also run in the Linux
//  harness (tools/swift_harness/run.sh): nothing here may touch UIKit, SwiftData or Photos.
//

import Testing
import Foundation
@testable import PurgeQuest

struct PhotoAccessTests {

    private let every: [PhotoAccess] = [.notAsked, .full, .limited, .denied, .restricted]

    // MARK: Reading the system status

    @Test func theSystemStatusesMapToTheirStates() {
        // PHAuthorizationStatus: notDetermined 0, restricted 1, denied 2, authorized 3, limited 4.
        #expect(PhotoAccess(rawStatus: 0) == .notAsked)
        #expect(PhotoAccess(rawStatus: 1) == .restricted)
        #expect(PhotoAccess(rawStatus: 2) == .denied)
        #expect(PhotoAccess(rawStatus: 3) == .full)
        #expect(PhotoAccess(rawStatus: 4) == .limited)
    }

    @Test func anUnknownStatusIsTreatedAsDeniedNotAsFine() {
        #expect(PhotoAccess(rawStatus: 99) == .denied)
        #expect(PhotoAccess(rawStatus: -1) == .denied)
    }

    // MARK: What each state allows

    @Test func onlyFullAndLimitedAccessCanReview() {
        #expect(every.filter(\.canReview) == [.full, .limited])
    }

    @Test func everythingShortOfFullAccessNeedsAttention() {
        #expect(every.filter(\.needsAttention) == [.notAsked, .limited, .denied, .restricted])
    }

    @Test func onlyDeniedAndLimitedCanBeFixedInSettings() {
        #expect(every.filter(\.canFixInSettings) == [.limited, .denied])
        // A restricted library cannot be opened by the user, so no state offers a Settings route it cannot use.
        #expect(PhotoAccess.restricted.canFixInSettings == false)
    }

    // MARK: Actions

    @Test func eachStateOffersTheRightAction() {
        #expect(PhotoAccess.notAsked.actionTitle == "Allow access")
        #expect(PhotoAccess.denied.actionTitle == "Open Settings")
        #expect(PhotoAccess.limited.actionTitle == "Manage")
        #expect(PhotoAccess.full.actionTitle == nil)
        #expect(PhotoAccess.restricted.actionTitle == nil)
    }

    @Test func aBlockedStateAlwaysSaysWhatIsWrongAndAnyRemedyIsReal() {
        for access in every where access != .full {
            #expect(!access.title.isEmpty)
            #expect(!access.message.isEmpty)
        }
        // Every state with an action is one the user can act on: the prompt, or Settings.
        for access in every where access.actionTitle != nil {
            #expect(access == .notAsked || access.canFixInSettings, "\(access) offers an action it cannot back up")
        }
    }

    // MARK: The rule: no clean bill of health without access

    @Test func noStateWithoutAccessEverClaimsTheLibraryIsClean() {
        let claims = ["all clear", "all reviewed", "nothing to review", "return another day"]
        for access in every where !access.canReview {
            let said = [access.title, access.message, access.chipText, access.emptyDiveTitle, access.emptyDiveMessage]
                .joined(separator: " ").lowercased()
            for claim in claims {
                #expect(!said.contains(claim), "\(access) says \"\(claim)\" about a library it cannot see")
            }
        }
    }

    @Test func aDiveThatFindsNothingTellsTheTruthForEachState() {
        #expect(PhotoAccess.full.emptyDiveTitle == "All clear")
        #expect(PhotoAccess.limited.emptyDiveTitle.contains("photos you allowed"))
        #expect(PhotoAccess.limited.emptyDiveMessage.contains("Settings"))
        #expect(PhotoAccess.denied.emptyDiveMessage == PhotoAccess.denied.message)
    }

    @Test func theOnboardingChipNamesEachState() {
        #expect(PhotoAccess.full.chipText == "Full access")
        #expect(PhotoAccess.notAsked.chipText == "Awaiting permission")
        #expect(Set(every.map(\.chipText)).count == every.count, "two states share one chip")
    }
}
