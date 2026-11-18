import Testing
import Foundation
@testable import PurgeQuest

@Suite struct ThumbnailTallyTests {

    @Test func theMostSpecificCauseNamesTheFailure() {
        #expect(ThumbnailFailure(cancelled: true, inCloud: true, errorDomain: "X", errorCode: 1).label == "request cancelled")
        #expect(ThumbnailFailure(inCloud: true, errorDomain: "NSURLErrorDomain", errorCode: -1009).label == "error NSURLErrorDomain -1009")
        #expect(ThumbnailFailure(inCloud: true).label == "in iCloud, not downloaded")
        #expect(ThumbnailFailure().label == "no reason given")
    }

    @Test func anEmptyTallySaysNothingHasLoaded() {
        #expect(ThumbnailTally().summary == "No photos have been loaded yet.")
    }

    @Test func aCleanScanSaysEverythingLoaded() {
        var tally = ThumbnailTally()
        for _ in 0..<3 { tally.recordLoaded(afterRetry: false) }
        #expect(tally.summary == "All 3 loaded.")
        tally.recordLoaded(afterRetry: true)
        #expect(tally.summary == "All 4 loaded. 1 needed a second try.")
    }

    @Test func failuresAreCountedWithTheirCausesMostCommonFirst() {
        var tally = ThumbnailTally()
        tally.recordLoaded(afterRetry: false)
        tally.recordLoaded(afterRetry: true)
        for _ in 0..<3 { tally.recordFailed(ThumbnailFailure(inCloud: true)) }
        tally.recordFailed(ThumbnailFailure(cancelled: true))
        #expect(tally.requested == 6)
        #expect(tally.failed == 4)
        #expect(tally.recovered == 1)
        #expect(tally.summary == "4 of 6 could not be loaded. 1 loaded on a second try.\n3 × in iCloud, not downloaded\n1 × request cancelled")
    }

    @Test func causesWithTheSameCountAreOrderedByName() {
        var tally = ThumbnailTally()
        tally.recordFailed(ThumbnailFailure(cancelled: true))
        tally.recordFailed(ThumbnailFailure())
        #expect(tally.summary.hasSuffix("1 × no reason given\n1 × request cancelled"))
    }

    @Test func theBoxCountsFromManyTasksAtOnce() async {
        let box = ThumbnailTallyBox()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<200 {
                group.addTask {
                    if index % 4 == 0 { box.recordFailed(ThumbnailFailure(inCloud: true)) }
                    else { box.recordLoaded(afterRetry: index % 4 == 1) }
                }
            }
        }
        let tally = box.current
        #expect(tally.requested == 200)
        #expect(tally.failed == 50)
        #expect(tally.recovered == 50)
        box.reset()
        #expect(box.current == ThumbnailTally())
    }

    @Test func theSummaryIsSavedForSettingsToShow() throws {
        let suite = "ThumbnailTallyTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ThumbnailTallyStore.loadSummary(from: defaults) == nil, "before any scan there is nothing to show")
        var tally = ThumbnailTally()
        tally.recordLoaded(afterRetry: false)
        ThumbnailTallyStore.save(tally, to: defaults)
        #expect(ThumbnailTallyStore.loadSummary(from: defaults) == "All 1 loaded.")
    }
}
