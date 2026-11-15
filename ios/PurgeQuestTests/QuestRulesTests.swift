//
//  QuestRulesTests.swift
//  PurgeQuestTests
//
//  What each daily quest counts, as the classifier decides it. A quest asks the player to delete N of a
//  named monster, and a monster is whatever MonsterClassifier says it is, in the order it checks. So the
//  quest's own line has to state that rule, ceilings and catch-alls included, or a player deletes a 1.2 GB
//  video for "files over 500 MB" and watches nothing move.
//
//  The first half pins the classifier's boundaries (so a rule cannot move without these failing); the
//  second half pins that the quest lines and the Bestiary lines state the same rules, with the same numbers.
//
//  Foundation only, so they run in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct QuestRulesTests {

    // MARK: - Builders

    /// A lone video with nothing unusual about it unless a parameter says so.
    private func video(
        bytes: Int64, seconds: Double = 30, width: Int = 1920, height: Int = 1080,
        screenRecording: Bool = false, timelapse: Bool = false
    ) -> MediaItem {
        var item = MediaItem(
            id: "v", kind: .video, creationDate: nil, pixelWidth: width, pixelHeight: height,
            durationSeconds: seconds, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenshot: false, isScreenRecording: screenRecording, isLivePhoto: false,
            isLooping: false, sharpness: nil, luminance: 0.5, highlightLuminance: nil
        )
        item.isTimelapse = timelapse
        return item
    }

    /// A lone photo with nothing unusual about it unless a parameter says so.
    private func photo(
        sharpness: Double? = 90, luminance: Double? = 0.5, highlight: Double? = nil,
        date: Date? = nil, screenshot: Bool = false, livePhoto: Bool = false, bytes: Int64 = 2_000_000
    ) -> MediaItem {
        MediaItem(
            id: "p", kind: .photo, creationDate: date, pixelWidth: 4000, pixelHeight: 3000,
            durationSeconds: 0, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenshot: screenshot, isScreenRecording: false, isLivePhoto: livePhoto,
            isLooping: false, sharpness: sharpness, luminance: luminance, highlightLuminance: highlight
        )
    }

    private func type(_ item: MediaItem) -> MonsterType { MonsterClassifier.classifySolo(item).monsterType }

    private var fiveYearsAgo: Date { Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? .distantPast }

    // MARK: - The rules the quest lines depend on

    @Test func aMemoryHogMinotaurIsAVideoOf500MBOrMoreButUnder1GB() {
        #expect(type(video(bytes: 499_999_999)) != .memoryHogMinotaur)
        #expect(type(video(bytes: 500_000_000)) == .memoryHogMinotaur)
        #expect(type(video(bytes: 999_999_999)) == .memoryHogMinotaur)
        #expect(type(video(bytes: 1_000_000_000)) == .gigabyteGorgon)
        // Only videos have a size rule: a huge photo is never a Minotaur or a Gorgon.
        #expect(type(photo(bytes: 900_000_000)).kind == .photo)
        #expect(type(photo(bytes: 900_000_000)) != .memoryHogMinotaur)
    }

    @Test func aVideoVampireIsAVideoOf100MBOrMoreButUnder500MBThatNothingElseClaims() {
        #expect(type(video(bytes: 99_999_999)) != .videoVampire)
        #expect(type(video(bytes: 100_000_000)) == .videoVampire)
        #expect(type(video(bytes: 499_999_999)) == .videoVampire)
        #expect(type(video(bytes: 500_000_000)) == .memoryHogMinotaur)
        // Each of these is claimed by another monster first, whatever its size.
        #expect(type(video(bytes: 100_000_000, width: 3840, height: 2160)) == .fourKKraken)
        #expect(type(video(bytes: 100_000_000, seconds: 121)) == .longTakeLeviathan)
        #expect(type(video(bytes: 100_000_000, screenRecording: true)) == .screenRecordingShade)
        #expect(type(video(bytes: 100_000_000, timelapse: true)) == .timelapsePhantom)
        #expect(type(video(bytes: 100_000_000, seconds: 4)) == .boringBlooper)
    }

    @Test func aLongTakeLeviathanIsAVideoOverTwoMinutesUnder500MBAndNot4K() {
        #expect(type(video(bytes: 20_000_000, seconds: 121)) == .longTakeLeviathan)
        #expect(type(video(bytes: 20_000_000, seconds: 120)) != .longTakeLeviathan)
        // A long screen recording is a Leviathan: length is checked before the screen-recording rule.
        #expect(type(video(bytes: 20_000_000, seconds: 300, screenRecording: true)) == .longTakeLeviathan)
        #expect(type(video(bytes: 499_999_999, seconds: 121)) == .longTakeLeviathan)
        // Size and resolution are checked first.
        #expect(type(video(bytes: 500_000_000, seconds: 121)) == .memoryHogMinotaur)
        #expect(type(video(bytes: 1_000_000_000, seconds: 121)) == .gigabyteGorgon)
        #expect(type(video(bytes: 20_000_000, seconds: 121, width: 3840, height: 2160)) == .fourKKraken)
    }

    @Test func aBlurBeastIsABlurryPhotoOrAPhotoNothingElseClaims() {
        #expect(type(photo(sharpness: 40)) == .blurBeast)
        // The catch-all: a sharp, ordinary photo that matches no other rule is also a Blur Beast.
        #expect(type(photo(sharpness: 90)) == .blurBeast)
        #expect(type(photo(sharpness: nil)) == .blurBeast)
        // A blurry photo from years ago is still blurry, not an Ancient Archive.
        #expect(type(photo(sharpness: 40, date: fiveYearsAgo)) == .blurBeast)
        // Anything another rule claims is not one.
        #expect(type(photo(screenshot: true)) == .screenshotSpecter)
        #expect(type(photo(livePhoto: true)) == .livePhotoLycan)
        #expect(type(photo(luminance: 0.05, highlight: 0.1)) == .darkWraith)
        #expect(type(photo(date: fiveYearsAgo)) == .ancientArchive)
    }

    /// The Duplicate Dragon quest is a photo quest, so every monster it counts has to be a photo.
    @Test func everyMonsterTheDuplicateQuestCountsIsAPhoto() throws {
        let quest = try #require(QuestCatalog.daily.first { $0.monsterType == .duplicateDragon })
        #expect(quest.kind == .photoSlay)
        let family = MonsterType.allCases.filter { $0.counts(as: .duplicateDragon) }
        #expect(family.count == 8)
        for monster in family { #expect(monster.kind == .photo, "\(monster) is counted by a photo quest") }
    }

    // MARK: - The quest lines state those rules

    private func line(_ monster: MonsterType) throws -> String {
        try #require(QuestCatalog.daily.first { $0.monsterType == monster }).subtitle
    }

    private func megabytes(_ bytes: Int64) -> String { "\(bytes / 1_000_000) MB" }
    private var gigabytes: String { "\(MonsterClassifier.gigabyte / 1_000_000_000) GB" }

    @Test func theMemoryHogQuestStatesBothEnds() throws {
        let text = try line(.memoryHogMinotaur)
        #expect(text.contains("videos of \(megabytes(MonsterClassifier.halfGigabyte)) or more but under \(gigabytes)"), "\(text)")
    }

    @Test func theVideoVampireQuestStatesBothEndsAndTheCatchAll() throws {
        let text = try line(.videoVampire)
        #expect(text.contains("videos of \(megabytes(MonsterClassifier.hundredMegabyte)) or more but under \(megabytes(MonsterClassifier.halfGigabyte))"), "\(text)")
        #expect(text.contains("that fit no other monster"), "\(text)")
    }

    @Test func theLeviathanQuestStatesLengthSizeAndResolution() throws {
        let text = try line(.longTakeLeviathan)
        #expect(text.contains("videos over two minutes"), "\(text)")
        #expect(text.contains("under \(megabytes(MonsterClassifier.halfGigabyte))"), "\(text)")
        #expect(text.contains("not 4K"), "\(text)")
    }

    @Test func theBlurBeastQuestSaysItAlsoTakesPhotosNothingElseClaims() throws {
        let text = try line(.blurBeast)
        #expect(text.contains("out-of-focus photos"), "\(text)")
        #expect(text.contains("photos that fit no other monster"), "\(text)")
    }

    @Test func theDuplicateQuestSaysWhichGroupsCount() throws {
        let text = try line(.duplicateDragon)
        #expect(text.contains("photos from duplicate groups"), "\(text)")
        for kind in ["copies", "bursts", "edits", "repeats"] { #expect(text.lowercased().contains(kind), "\(text) never says \(kind)") }
    }

    /// The count builds across the whole day and across dives (a quest lasts a day and `updateQuests` adds
    /// to it), so "in one session" was wrong.
    @Test func theStorageQuestIsADayNotASession() throws {
        let quest = try #require(QuestCatalog.daily.first { $0.kind == .mbFreed })
        #expect(quest.subtitle.contains("\(quest.targetCount) MB"), "\(quest.subtitle)")
        #expect(quest.subtitle.contains("today"), "\(quest.subtitle)")
        #expect(!quest.subtitle.lowercased().contains("session"), "\(quest.subtitle)")
    }

    @Test func theAnyMonsterQuestSaysEveryMonsterCounts() throws {
        let quest = try #require(QuestCatalog.daily.first { $0.kind == .anySlay })
        #expect(quest.subtitle.contains("photos or videos"), "\(quest.subtitle)")
        #expect(quest.subtitle.contains("Any monster counts"), "\(quest.subtitle)")
    }

    // MARK: - The Bestiary states them too

    @Test func theBestiaryStatesTheSameRulesAsTheQuests() {
        #expect(MonsterType.memoryHogMinotaur.signalDescription == "Videos of \(megabytes(MonsterClassifier.halfGigabyte)) or more but under \(gigabytes)")
        #expect(MonsterType.gigabyteGorgon.signalDescription == "Videos of \(gigabytes) or more")
        #expect(MonsterType.videoVampire.signalDescription == "Videos of \(megabytes(MonsterClassifier.hundredMegabyte)) or more but under \(megabytes(MonsterClassifier.halfGigabyte)) that fit no other monster")
        #expect(MonsterType.longTakeLeviathan.signalDescription == "Videos over two minutes, under \(megabytes(MonsterClassifier.halfGigabyte)) and not 4K")
        #expect(MonsterType.fourKKraken.signalDescription == "4K videos (3840 pixels or wider) under \(megabytes(MonsterClassifier.halfGigabyte))")
        #expect(MonsterType.blurBeast.signalDescription == "Out-of-focus photos, and photos that fit no other monster")
    }
}
