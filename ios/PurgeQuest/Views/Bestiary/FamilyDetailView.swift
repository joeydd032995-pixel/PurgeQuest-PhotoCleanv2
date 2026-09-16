//
//  FamilyDetailView.swift
//  PurgeQuest
//
//  One family's page: monsters grouped by rarity, each with silhouette,
//  lore, unlockable title, plain-language reason, review guidance, encounter
//  stats, and its rarity frame + reward profile.
//

import SwiftUI
import SwiftData

struct FamilyDetailView: View {
    let family: MonsterFamily

    @Query private var sightings: [MonsterSightingRecord]
    @Query private var sparedRecords: [SparedMediaRecord]
    @Query private var deletedRecords: [DeletedMediaRecord]

    private var types: [MonsterType] {
        MonsterType.allCases
            .filter { $0.family == family }
            .sorted { $0.rarity == $1.rarity ? $0.displayName < $1.displayName : $0.rarity > $1.rarity }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(types, id: \.rawValue) { type in
                    MonsterEntryCard(
                        type: type,
                        stats: stats(for: type)
                    )
                }
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .navigationTitle(family.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(family.tagline)
                .font(.callout)
                .foregroundStyle(.textSecondary)
            if family == .archiveRelics {
                Label("Old photos are memories, not junk. Reviewing is always rewarded.", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.xpViolet)
            }
            if family == .glitchborn {
                Label("Broken media is never deleted for you — review carefully.", systemImage: "hand.raised.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.combatCrimson)
            }
        }
    }

    private func stats(for type: MonsterType) -> BestiaryService.MonsterStats {
        let sighted = sightings.first { $0.monsterType == type }
        var stats = BestiaryService.MonsterStats()
        stats.encountered = sighted?.encounteredCount ?? 0
        stats.spared = sparedRecords.filter { $0.monsterType == type }.count
        let slain = deletedRecords.filter { $0.monsterType == type }
        stats.slain = slain.count
        stats.bytesReclaimed = slain.reduce(0) { $0 + $1.fileSizeBytes }
        return stats
    }
}

/// One monster entry in a family page. Locked entries show a silhouette
/// until first encountered.
private struct MonsterEntryCard: View {
    let type: MonsterType
    let stats: BestiaryService.MonsterStats

    private var isDiscovered: Bool { stats.isDiscovered }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                silhouette
                VStack(alignment: .leading, spacing: 3) {
                    Text(isDiscovered ? type.displayName : "???")
                        .font(.dungeonHeader)
                        .foregroundStyle(.textPrimary)
                    HStack(spacing: 6) {
                        Text(type.rarity.displayName)
                            .font(.system(size: 10, weight: .black).monospaced())
                            .tracking(0.6)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(type.rarity.frameColor.opacity(0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(type.rarity.frameColor.opacity(0.7), lineWidth: 1))
                            .foregroundStyle(type.rarity.frameColor)
                        if type.rarity.hasCrownBadge {
                            Image(systemName: "crown.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.questAmber)
                        }
                        Text(type.kind == .photo ? "Photo" : "Video")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer()
            }

            if isDiscovered {
                Text(type.lore)
                    .font(.callout.italic())
                    .foregroundStyle(.white.opacity(0.92))
                unlockableTitle
                whySection
                statsSection
            } else {
                Text("Undiscovered — venture deeper into the dungeon.")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(type.rarity.frameColor.opacity(isDiscovered ? 0.7 : 0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isDiscovered
                ? "\(type.rarity.displayName) monster \(type.displayName). \(type.lore). Encountered \(stats.encountered) times, spared \(stats.spared), slain \(stats.slain)."
                : "Undiscovered \(type.rarity.displayName) monster."
        )
    }

    private var silhouette: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonVoid)
                .frame(width: 56, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(type.rarity.frameColor.opacity(0.4), lineWidth: 1))
            Image(systemName: type.symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(isDiscovered ? type.accentColor : .dungeonAsh)
                .opacity(isDiscovered ? 1 : 0.6)
        }
    }

    private var unlockableTitle: some View {
        Label("Title: \(type.unlockableTitle)", systemImage: "rosette")
            .font(.caption.weight(.bold))
            .foregroundStyle(.questAmber)
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Why it appears", systemImage: "questionmark.circle.fill")
                .font(.caption2.weight(.black))
                .tracking(0.5)
                .foregroundStyle(.textSecondary)
            Text(type.signalDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textPrimary)
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: type.defaultsToCarefulReview ? "eye.fill" : "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(type.defaultsToCarefulReview ? .questAmber : .gemEmerald)
                Text(type.reviewGuidance)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 14) {
                statBlock(value: "\(stats.encountered)", label: "Met", tint: .textPrimary)
                statBlock(value: "\(stats.spared)", label: "Spared", tint: .gemEmerald)
                statBlock(value: "\(stats.slain)", label: "Slain", tint: .combatCrimson)
                Spacer()
            }
            HStack(spacing: 8) {
                Label(ByteCountFormatter.string(fromByteCount: stats.bytesReclaimed, countStyle: .file) + " reclaimed", systemImage: "internaldrive.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.gemEmerald)
                Text("·")
                    .foregroundStyle(.textTertiary)
                Text(type.rarity.rewardProfile)
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func statBlock(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.textTertiary)
        }
    }
}
