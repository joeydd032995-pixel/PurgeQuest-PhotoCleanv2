//
//  RoomSummaryView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

struct RoomSummaryView: View {
    @Bindable var combat: CombatViewModel
    let hero: Hero
    let quests: [Quest]
    let onContinue: () -> Void
    let onExit: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var markedCount: Int { combat.markedCount }
    private var keptCount: Int { combat.pendingDecisions.count - combat.markedCount }
    private var isLastRoom: Bool { combat.progress.room >= combat.progress.totalRooms }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                lootSummary
                pendingGrid
                questProgressPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(DungeonBackgroundView())
        // The commit is pinned: on a 20-item room it used to sit about a screen and a third down the page.
        .safeAreaInset(edge: .bottom, spacing: 0) { commitBar }
    }

    /// "Room 2" over "12 marked, 8 kept". It used to say "Room Cleared" before anything was cleared.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.callout.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                    .foregroundStyle(.textPrimary)
            }
            .disabled(combat.phase == .purging)
            .accessibilityLabel("Exit dungeon")

            VStack(alignment: .leading, spacing: 2) {
                Text("Room \(combat.roomNumber)")
                    .font(.dungeonScreenTitle)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(Wording.roomVerdict(marked: markedCount, kept: keptCount))
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var lootSummary: some View {
        HStack(spacing: 10) {
            StatTile(icon: "internaldrive.fill", label: "To move", value: ByteCountFormatter.string(fromByteCount: combat.pendingDeleteByteTotal, countStyle: .file), tint: .videoSapphire)
            StatTile(icon: "arrow.up.forward", label: "XP", value: "+\(estimatedXP)", tint: .questAmber)
            StatTile(icon: "diamond.fill", label: "Gems", value: "+\(estimatedGems)", tint: .gemEmerald)
        }
    }

    private var estimatedXP: Int {
        combat.pendingDecisions.filter { $0.willDelete }.reduce(0) { $0 + $1.xpReward }
    }

    private var estimatedGems: Int {
        combat.pendingDecisions.filter { $0.willDelete }.reduce(0) { $0 + $1.gemReward }
    }

    private var pendingGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Review this room")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("Tap a card to switch")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(combat.pendingDecisions) { decision in
                    DecisionTile(decision: decision) {
                        combat.toggleDecision(for: decision.id)
                        HapticsService.shared.light()
                    }
                }
            }
        }
    }

    /// Live quest math for THIS purge: each active quest's projected count
    /// after the marked items are deleted, simulated with the same rules the
    /// ViewModel applies on confirm (`GameDataService.updateQuests`). Quests
    /// only advance when the room is moved to Recently Deleted: this makes that visible.
    private var questDeltas: [UUID: Int] {
        var result: [UUID: Int] = [:]
        for decision in combat.pendingDecisions where decision.willDelete && decision.awardsProgress {
            let slain = decision.item.monsterType
            let mb = Double(decision.item.estimatedBytes) / 1_048_576.0
            for q in quests where !q.completed {
                switch q.kind {
                case .photoSlay:
                    if slain.kind == .photo, q.monsterType.map(slain.counts(as:)) ?? false {
                        result[q.id, default: 0] += 1
                    }
                case .videoSlay:
                    if slain.kind == .video, q.monsterType.map(slain.counts(as:)) ?? false {
                        result[q.id, default: 0] += 1
                    }
                case .anySlay:
                    result[q.id, default: 0] += 1
                case .mbFreed:
                    result[q.id, default: 0] += Int(mb.rounded())
                }
            }
        }
        return result
    }

    private var questProgressPanel: some View {
        let deltas = questDeltas
        let active = quests.filter { !$0.completed || (deltas[$0.id] ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quest progress")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("after this room")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            if active.isEmpty {
                Text("No active quests right now.")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            ForEach(active) { q in
                let delta = deltas[q.id] ?? 0
                HStack {
                    Text(q.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if delta > 0 {
                        Text("+\(delta)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.gemEmerald)
                    }
                    Text("\(min(q.currentCount + delta, q.targetCount)) / \(q.targetCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1)))
    }

    /// The pinned bar. One destructive button that says how many and where, then a quiet way to keep the
    /// room. It goes straight to Photos' own delete dialog: the in-app "Move N items?" alert in front of it
    /// is gone, so the player confirms once in the system's words, not twice.
    private var commitBar: some View {
        VStack(spacing: 6) {
            if markedCount > 0 {
                Button(action: commit) {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            if combat.phase == .purging { ProgressView().tint(.white) }
                            Text(Wording.moveToRecentlyDeleted(markedCount))
                                .font(.headline.weight(.bold))
                        }
                        Text(Wording.recoverableNote(size: ByteCountFormatter.string(fromByteCount: combat.pendingDeleteByteTotal, countStyle: .file)))
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.combatCrimson)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.combatCrimsonDeep, lineWidth: 1))
                }
                .disabled(combat.phase == .purging)
                .accessibilityHint("Photos asks you to confirm. You can restore them for 30 days.")

                Button(action: onContinue) {
                    Text(isLastRoom ? "Keep all, finish dive" : "Keep all, skip room")
                        .font(.callout)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(combat.phase == .purging)
            } else {
                Button(action: onContinue) {
                    Text(isLastRoom ? "Finish dive" : "Next room")
                }
                .buttonStyle(.gold(fullWidth: true))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Color.dungeonStone
                .overlay(alignment: .top) { Rectangle().fill(Color.dungeonAsh).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func commit() {
        Task { await combat.confirmRoom(hero: hero, context: modelContext, quests: quests) }
    }
}

private struct DecisionTile: View {
    let decision: PendingDecision
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color.dungeonStoneLight
                    .overlay {
                        if let thumb = decision.item.thumbnail {
                            Image(uiImage: thumb).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                        } else {
                            Image(systemName: decision.item.monsterType.symbol)
                                .foregroundStyle(decision.item.monsterType.accentColor)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(decision.willDelete ? Color.combatCrimson : Color.dungeonAsh, lineWidth: 2)
                    )
                if decision.item.kind == .video {
                    VStack {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.caption2.weight(.bold))
                                .padding(4)
                                .background(Circle().fill(.black.opacity(0.6)))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(decision.item.formattedDuration)
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.7)))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(6)
                }
                if !decision.willDelete {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gemEmerald.opacity(0.35))
                    Image(systemName: "shield.fill")
                        .font(.title)
                        .foregroundStyle(.gemEmerald)
                } else {
                    VStack(spacing: 3) {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.caption.weight(.bold))
                            .padding(4)
                            .background(Circle().fill(Color.combatCrimson))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(decision.item.kind == .video ? "Video" : "Photo")
        .accessibilityValue(decision.willDelete ? "Marked to move to Recently Deleted" : "Kept")
        .accessibilityHint("Switches between marked and kept")
    }
}
