//
//  ContentReachabilityTests.swift
//  PurgeQuestTests
//
//  Every monster has a way to be summoned, and every quest and seasonal bonus names only monsters
//  that can be. The table below builds, for each MonsterType, a situation the classifier turns into
//  exactly that monster. A new MonsterType without a witness fails the first test, so game content
//  can never again point at a monster nothing summons.
//
//  Being summonable from a hand-built item is not the same as turning up in a real library, so the
//  last section pins the two ways a monster used to be reachable here and not on a phone: a rule that
//  an older rule always got to first, and a signal nothing on the device ever set (CaptureSignalTests
//  covers the second).
//
//  Foundation only: the content comes from GameContent.swift, so this runs in the Linux harness too.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ContentReachabilityTests {

    // MARK: - Building blocks

    private static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let day: TimeInterval = 86_400
    private static let lookAlike: UInt64 = 0xAAAA_5555_AAAA_5555

    private func item(
        _ id: String = "a",
        kind: MediaKind = .photo,
        width: Int = 4000,
        height: Int = 3000,
        bytes: Int64 = 2_000_000,
        duration: Double = 0,
        capturedAt: Date? = ContentReachabilityTests.epoch,
        screenshot: Bool = false,
        livePhoto: Bool = false,
        screenRecording: Bool = false,
        looping: Bool = false,
        sharpness: Double? = 60,
        luminance: Double? = 0.5
    ) -> MediaItem {
        MediaItem(
            id: id, kind: kind, creationDate: capturedAt, pixelWidth: width, pixelHeight: height,
            durationSeconds: duration, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenshot: screenshot, isScreenRecording: screenRecording, isLivePhoto: livePhoto,
            isLooping: looping, sharpness: sharpness, luminance: luminance
        )
    }

    /// What the classifier calls a lone item, judged one day after the epoch.
    private func alone(_ item: MediaItem) -> MonsterType {
        MonsterClassifier.classifySolo(item, now: Self.epoch.addingTimeInterval(Self.day)).monsterType
    }

    private func clip(
        duration: Double = 30, bytes: Int64 = 20_000_000, width: Int = 1920, height: Int = 1080,
        luminances: [Double]? = nil, screenRecording: Bool = false, looping: Bool = false
    ) -> MonsterType {
        var video = item("clip", kind: .video, width: width, height: height, bytes: bytes,
                         duration: duration, screenRecording: screenRecording, looping: looping)
        if let luminances { video.frameSignals = VideoFrameSignals.evaluate(luminances: luminances) }
        return alone(video)
    }

    /// What the classifier calls the oldest of several look-alike photos captured `gap` seconds apart.
    private func summonedByCopies(
        count: Int, gap: TimeInterval, screenshots: Bool = false, cropped: Bool = false, identicalFiles: Bool = false
    ) -> MonsterType? {
        var items: [MediaItem] = []
        var prints: [MediaFingerprint] = []
        for i in 0..<count {
            let date = Self.epoch.addingTimeInterval(Double(i) * gap)
            let width = cropped && i == 1 ? 3000 : 4000
            let height = cropped && i == 1 ? 2000 : 3000
            let size = Int64(2_000_000 + i * 1_001)
            let copy = item("copy\(i)", width: width, height: height, bytes: size, capturedAt: date, screenshot: screenshots)
            items.append(copy)
            prints.append(MediaFingerprint(
                assetID: copy.id, byteSize: size, pixelWidth: width, pixelHeight: height, durationSeconds: 0,
                creationDate: date, isFavorite: false, isScreenshot: screenshots, hasEdits: false,
                isScreenRecording: false, dHash: Self.lookAlike, sharpness: 60,
                contentHash: identicalFiles ? "same" : nil
            ))
        }
        return MonsterClassifier.classify(items: items, fingerprints: prints).classifications["copy0"]?.monsterType
    }

    /// One witness per monster: the monster we expect, and the one the classifier actually gives.
    private func witnesses() -> [(expected: MonsterType, actual: MonsterType?)] {
        var w: [(expected: MonsterType, actual: MonsterType?)] = []

        // Duplicate Dragons: clusters of look-alikes.
        w.append((.perfectPairWyrmling, summonedByCopies(count: 2, gap: 3_600, identicalFiles: true)))
        w.append((.duplicateDragon, summonedByCopies(count: 2, gap: 10 * Self.day)))
        w.append((.burstHydra, summonedByCopies(count: 3, gap: 1)))
        w.append((.cloneChimera, summonedByCopies(count: 2, gap: 60, cropped: true)))
        w.append((.screenshotTwin, summonedByCopies(count: 2, gap: Self.day, screenshots: true)))
        w.append((.downloadDrake, summonedByCopies(count: 2, gap: 3_600)))
        w.append((.albumEcho, summonedByCopies(count: 2, gap: 60 * Self.day)))
        w.append((.hoardHydra, summonedByCopies(count: 6, gap: Self.day)))

        // Photos on their own.
        w.append((.blurBeast, alone(item(sharpness: 3))))
        w.append((.screenshotSpecter, alone(item(screenshot: true))))
        w.append((.lowQualityLich, alone(item(width: 1_000, height: 3_000))))
        w.append((.darkWraith, alone(item(luminance: 0.1))))
        w.append((.thumbGoblin, alone(item(width: 400, height: 300))))
        w.append((.livePhotoLycan, alone(item(livePhoto: true))))
        w.append((.ancientArchive, alone(item(capturedAt: Self.epoch.addingTimeInterval(-4 * 365 * Self.day)))))
        w.append((.panoramaColossus, alone(item(width: 10_000, height: 3_000))))
        w.append((.staticHusk, alone(item(bytes: 0))))
        var unloadable = item()
        unloadable.loadFailed = true
        w.append((.nullPortrait, alone(unloadable)))
        var document = item()
        document.visionSignals = VisionTextSignals(characterCount: 500, regionCount: 8, hasBarcode: false)
        w.append((.tomeWraith, alone(document)))
        var ticket = item()
        ticket.visionSignals = VisionTextSignals(characterCount: 0, regionCount: 0, hasBarcode: true)
        w.append((.sigilSpecter, alone(ticket)))

        // Videos.
        w.append((.gigabyteGorgon, clip(bytes: 1_200_000_000)))
        w.append((.memoryHogMinotaur, clip(bytes: 600_000_000)))
        w.append((.fourKKraken, clip(width: 3_840, height: 2_160)))
        w.append((.longTakeLeviathan, clip(duration: 200)))
        w.append((.screenRecordingShade, clip(screenRecording: true)))
        w.append((.timelapsePhantom, clip(looping: true)))
        w.append((.flickerWraith, clip(duration: 10, luminances: [0.2, 0.9, 0.15])))
        w.append((.framedPhantom, clip(duration: 10, luminances: [0.5, 0.501, 0.502])))
        w.append((.shakyGhost, clip(duration: 10, luminances: [0.3, 0.5, 0.35])))
        w.append((.pocketPoltergeist, clip(duration: 1.2)))
        w.append((.boringBlooper, clip(duration: 3.5)))
        w.append((.videoVampire, clip(bytes: 150_000_000)))
        w.append((.mistWraith, clip(duration: 10)))
        w.append((.tatterWraith, clip(duration: 45)))
        w.append((.voidWraith, clip(duration: 90)))
        w.append((.corruptedCodec, clip(duration: 0)))
        return w
    }

    // MARK: - The roster

    @Test func everyMonsterHasExactlyOneWitness() {
        let expected = witnesses().map(\.expected)
        #expect(Set(expected) == Set(MonsterType.allCases), "monsters without a witness: \(Set(MonsterType.allCases).subtracting(expected))")
        #expect(expected.count == Set(expected).count, "a monster has two witnesses")
    }

    @Test func theClassifierSummonsEveryMonster() {
        for witness in witnesses() {
            #expect(witness.actual == witness.expected, "expected \(witness.expected), the classifier gave \(String(describing: witness.actual))")
        }
    }

    // MARK: - Content that names monsters

    @Test func everyQuestNamesAMonsterItsKindCanSlay() {
        let pool = QuestCatalog.daily
        #expect(!pool.isEmpty)
        for quest in pool {
            switch quest.kind {
            case .photoSlay:
                let target = quest.monsterType
                #expect(target?.kind == .photo, "\(quest.title) is a photo quest but names \(String(describing: target))")
            case .videoSlay:
                let target = quest.monsterType
                #expect(target?.kind == .video, "\(quest.title) is a video quest but names \(String(describing: target))")
            case .mbFreed, .anySlay:
                #expect(quest.monsterType == nil, "\(quest.title) should not name a monster")
            }
        }
    }

    @Test func everyQuestTargetCanBeSummoned() {
        let summonable = Set(witnesses().filter { $0.actual == $0.expected }.map(\.expected))
        for quest in QuestCatalog.daily {
            guard let target = quest.monsterType else { continue }
            #expect(summonable.contains(target), "\(quest.title) targets \(target), which nothing summons")
        }
    }

    @Test func everySeasonalBonusNamesAMonsterThatCanBeSummoned() {
        let summonable = Set(witnesses().filter { $0.actual == $0.expected }.map(\.expected))
        #expect(!SeasonalBonusCatalog.byEventID.isEmpty)
        for (event, bonus) in SeasonalBonusCatalog.byEventID {
            #expect(!bonus.monsters.isEmpty, "\(event) rewards no monster")
            #expect(bonus.multiplier > 1, "\(event) pays no bonus")
            for monster in bonus.monsters {
                #expect(summonable.contains(monster), "\(event) rewards \(monster), which nothing summons")
            }
        }
    }

    // MARK: - Reachable in a real library, not only in a fixture

    /// Dives are dealt oldest first, so in a library that goes back years every photo of the first
    /// many dives is old. A photo monster that game content names must still be summoned there.
    @Test func thePhotoMonstersContentNamesAreSummonedInAnOldLibraryToo() {
        let longAgo = Self.epoch.addingTimeInterval(-6 * 365 * Self.day)
        var named = Set(QuestCatalog.daily.compactMap(\.monsterType))
        for bonus in SeasonalBonusCatalog.byEventID.values { named.formUnion(bonus.monsters) }

        let oldLibrary: [MonsterType: MediaItem] = [
            .blurBeast: item(capturedAt: longAgo, sharpness: 3),
            .darkWraith: item(capturedAt: longAgo, luminance: 0.1),
            .lowQualityLich: item(width: 1_000, height: 3_000, capturedAt: longAgo),
            .screenshotSpecter: item(capturedAt: longAgo, screenshot: true),
            .ancientArchive: item(capturedAt: longAgo)
        ]
        // Duplicate Dragons come from clusters, which never look at age.
        let soloPhotos = named.filter { $0.kind == .photo && $0.family != .duplicateDragons }
        #expect(soloPhotos == Set(oldLibrary.keys), "a photo monster named by content has no old-library case: \(soloPhotos.subtracting(oldLibrary.keys))")
        for (monster, photo) in oldLibrary {
            #expect(alone(photo) == monster, "an old photo that should be \(monster) was called \(alone(photo))")
        }
    }
}
