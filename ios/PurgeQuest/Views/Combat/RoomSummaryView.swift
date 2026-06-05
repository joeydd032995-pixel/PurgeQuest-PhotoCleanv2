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
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(LinearGradient.amberGlow)
                    .shadow(color: .questAmber.opacity(0.5), radius: 12)
                    .padding(.top, 20)

                lootSummary

                pendingGrid

                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(DungeonBackgroundView(intensity: 0.5))
    }

    private var lootSummary: some View {
        let mb = Double(combat.pendingDeleteByteTotal) / 1_048_576.0
        let label: String = mb >= 1024 ? String(format: "%.2f GB", mb / 1024.0) : String(format: "%.0f MB", mb)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(icon: "internaldrive.fill", label: "To free", value: label, tint: .gemEmerald)
                StatTile(icon: "sparkle", label: "XP", value: "+\(estimatedXP)", tint: .questAmber)
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
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dungeonAsh, lineWidth: 1)))
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
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.questAmber.opacity(0.12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.4), lineWidth: 1)))
            }
            Button {
                confirming = true
            } label: {
                HStack {
                    if combat.phase == .purging { ProgressView().tint(.dungeonVoid) }
                    Text("Confirm Purge")
                        .font(.headline.weight(.heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.crimsonGlow)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .combatCrimson.opacity(0.5), radius: 12)
            }
            .disabled(combat.pendingPhotoCount + combat.pendingVideoCount == 0 || combat.phase == .purging)

            Button {
                onContinue()
            } label: {
                Text("Skip — keep all this room")
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
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
                                .background(Capsule().fill(.black.opacity(0.7)))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(6)
                }
                if !decision.willDelete {
                    RoundedRectangle(cornerRadius: 10).fill(Color.gemEmerald.opacity(0.35))
                    Image(systemName: "shield.fill")
                        .font(.title)
                        .foregroundStyle(.gemEmerald)
                        .shadow(color: .black, radius: 3)
                } else {
                    VStack {
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
    }
}
