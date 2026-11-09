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

    @Environment(\.modelContext) private var modelContext
    @State private var confirming: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Room Cleared")
                    .font(.dungeonTitle)
                    .foregroundStyle(.questAmber)
                    .padding(.top, 20)

                lootSummary

                pendingGrid

                questProgressPanel

                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(DungeonBackgroundView())
    }

    private var lootSummary: some View {
        let mb = Double(combat.pendingDeleteByteTotal) / 1_048_576.0
        let label: String = mb >= 1024 ? String(format: "%.2f GB", mb / 1024.0) : String(format: "%.0f MB", mb)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(icon: "internaldrive.fill", label: "To free", value: label, tint: .gemEmerald)
                StatTile(icon: "arrow.up.forward", label: "XP", value: "+\(estimatedXP)", tint: .questAmber)
                StatTile(icon: "diamond.fill", label: "Gems", value: "+\(estimatedGems)", tint: .gemEmerald)
            }
            HStack(spacing: 10) {
                StatTile(icon: "photo.fill", label: "Photos to purge", value: "\(combat.pendingPhotoCount)", tint: .questAmber)
                StatTile(icon: "video.fill", label: "Videos to purge", value: "\(combat.pendingVideoCount)", tint: .videoSapphire)
            }
            if combat.peakCombo > 0 {
                HStack {
                    Image(systemName: "bolt.fill").foregroundStyle(.questAmber)
                    Text("Peak combo: \(combat.peakCombo)×")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1)))
            }
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
                Text("Review purge list")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("Tap to toggle")
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
    /// only advance at "Confirm Purge" — this makes that visible.
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
                Text("after this purge")
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

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if combat.pendingPhotoCount + combat.pendingVideoCount == 0 {
                Text("No items selected for purge.")
                    .font(.callout)
                    .foregroundStyle(.textSecondary)
            }
            if combat.pendingDeleteByteTotal > 100_000_000, combat.pendingVideoCount > 0 {
                Label("Large videos will move to Recently Deleted (recoverable for 30 days).", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.questAmber)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.questAmber.opacity(0.12)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.questAmber.opacity(0.4), lineWidth: 1)))
            }
            Button {
                confirming = true
            } label: {
                HStack {
                    if combat.phase == .purging { ProgressView().tint(.white) }
                    Text("Confirm Purge")
                        .font(.dungeonHeader)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.combatCrimson)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.combatCrimsonDeep, lineWidth: 1))
            }
            .disabled(combat.pendingPhotoCount + combat.pendingVideoCount == 0 || combat.phase == .purging)

            Button {
                onContinue()
            } label: {
                Text("Skip room, keep all items")
                    .font(.callout)
                    .foregroundStyle(.textSecondary)
            }
        }
        .alert("Move \(combat.pendingPhotoCount + combat.pendingVideoCount) items to Recently Deleted?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Purge", role: .destructive) {
                Task {
                    await combat.confirmRoom(hero: hero, context: modelContext, quests: quests)
                }
            }
        } message: {
            Text("Items can be recovered from the Photos app for 30 days.")
        }
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
                        if decision.xpReward > 0 || decision.gemReward > 0 {
                            Text("+\(decision.xpReward) XP · +\(decision.gemReward)")
                                .font(.system(size: 9, weight: .black).monospacedDigit())
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.65)))
                                .foregroundStyle(.questAmber)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
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
    }
}
