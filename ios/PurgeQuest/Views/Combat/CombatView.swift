//
//  CombatView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

struct CombatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var heroes: [Hero]
    @Query private var quests: [Quest]

    @State private var combat = CombatViewModel()
    @State private var shakeOffset: CGFloat = 0
    @State private var fxTrigger: Int = 0

    var body: some View {
        ZStack {
            DungeonBackgroundView(intensity: dungeonIntensity)
                .offset(x: shakeOffset)

            content
                .offset(x: shakeOffset)

            ParticleBurstView(trigger: combat.deleteFlashTrigger,
                              palette: [.combatCrimson, .questAmber, .questAmberDeep])
                .ignoresSafeArea()

            ParticleBurstView(trigger: combat.spareFlashTrigger,
                              palette: [.gemEmerald, .videoSapphire],
                              symbol: "shield.fill")
                .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .task {
            guard let hero = heroes.first else { return }
            await combat.bootstrap(includeVideos: appState.includeVideos, videoOnly: appState.videoOnlyMode, hero: hero, context: modelContext)
        }
        .onChange(of: combat.screenShakeTrigger) { _, _ in
            shake()
        }
    }

    private var dungeonIntensity: Double {
        Double(min(combat.roomNumber - 1, CombatViewModel.totalRoomsPerSession - 1)) / Double(CombatViewModel.totalRoomsPerSession - 1)
    }

    @ViewBuilder
    private var content: some View {
        switch combat.phase {
        case .loading:
            loadingView
        case .empty:
            emptyView
        case .fighting:
            fightingView
        case .roomSummary, .purging:
            if let hero = heroes.first {
                RoomSummaryView(combat: combat, hero: hero, quests: quests) {
                    Task { await combat.skipRoom(hero: hero, context: modelContext, quests: quests) }
                }
            }
        case .sessionComplete:
            sessionCompleteView
        case .defeated:
            defeatedView
        case .error(let msg):
            errorView(msg)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView().tint(.questAmber).scaleEffect(1.4)
            Text("Summoning monsters from your library…")
                .font(.callout).foregroundStyle(.textSecondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 64)).foregroundStyle(.gemEmerald)
            Text("All clear")
                .font(.dungeonTitle).foregroundStyle(.textPrimary)
            Text("Your library has nothing to review right now.\nReturn another day.")
                .font(.callout).foregroundStyle(.textSecondary).multilineTextAlignment(.center)
            Button("Back to Library") {
                exit()
            }
            .padding(.vertical, 12).padding(.horizontal, 24)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.questAmber))
            .foregroundStyle(.dungeonVoid)
        }
        .padding()
    }

    private var fightingView: some View {
        VStack(spacing: 12) {
            CombatHUD(
                heroHP: combat.heroCurrentHP,
                heroMaxHP: combat.heroMaxHP,
                combo: combat.combo,
                roomNumber: combat.roomNumber,
                totalRooms: CombatViewModel.totalRoomsPerSession,
                remaining: combat.roomRemaining,
                onExit: { exit() }
            )
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ZStack {
                if let next = combat.nextItem {
                    SwipeMediaCard(item: next, isFront: false, onDelete: {}, onSpare: {})
                        .padding(.horizontal, 36)
                        .padding(.vertical, 28)
                }
                if let top = combat.topItem, let hero = heroes.first {
                    SwipeMediaCard(
                        item: top,
                        isFront: true,
                        onDelete: { combat.decideDelete(top, hero: hero) },
                        onSpare: {
                            if let hero = heroes.first { combat.decideSpare(top, hero: hero, context: modelContext) }
                        }
                    )
                    .id(top.id)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 16) {
                Button { if let top = combat.topItem, let hero = heroes.first { combat.decideDelete(top, hero: hero) } } label: {
                    Label("DELETE", systemImage: "xmark")
                        .font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.combatCrimson))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.combatCrimsonDeep, lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .accessibilityHint("Mark this item for deletion")

                Button { if let top = combat.topItem, let hero = heroes.first { combat.decideSpare(top, hero: hero, context: modelContext) } } label: {
                    Label("SPARE", systemImage: "shield.fill")
                        .font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStoneLight))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                        .foregroundStyle(.textPrimary)
                }
                .accessibilityHint("Spare this item, take damage")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.questAmber)
                .frame(width: 116, height: 116)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(3))
                )
            Text("Dungeon Complete")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
            VStack(spacing: 8) {
                summaryRow(label: "Photos purged", value: "\(combat.sessionPhotosDeleted)", tint: .questAmber)
                summaryRow(label: "Videos purged", value: "\(combat.sessionVideosDeleted)", tint: .videoSapphire)
                summaryRow(label: "Storage freed", value: ByteCountFormatter.string(fromByteCount: combat.sessionBytesFreed, countStyle: .file), tint: .gemEmerald)
                summaryRow(label: "XP earned", value: "+\(combat.sessionXP)", tint: .questAmber)
                summaryRow(label: "Gems earned", value: "+\(combat.sessionGems)", tint: .gemEmerald)
                summaryRow(label: "Peak combo", value: "\(combat.peakCombo)×", tint: .combatCrimson)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1)))
            .padding(.horizontal, 24)

            if combat.hasMoreItems, let hero = heroes.first {
                Button {
                    combat.continueDeeper(hero: hero)
                } label: {
                    Label("Continue Deeper", systemImage: "arrow.down.to.line.compact")
                        .font(.dungeonHeader)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.questAmber))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmberDeep, lineWidth: 1))
                        .foregroundStyle(.dungeonVoid)
                }
                .accessibilityHint("Start another pass without returning to the Library")
            }

            Button("Return to Library") {
                exit()
            }
            .font(.headline)
            .padding(.vertical, 14).padding(.horizontal, 28)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        combat.hasMoreItems
                            ? AnyShapeStyle(Color.dungeonStone)
                            : AnyShapeStyle(Color.questAmber)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: combat.hasMoreItems ? 1 : 0))
            )
            .foregroundStyle(combat.hasMoreItems ? Color.textPrimary : Color.dungeonVoid)
        }
        .padding()
    }

    private var defeatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.combatCrimson)
                .frame(width: 116, height: 116)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.combatCrimson.opacity(0.6), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.combatCrimson.opacity(0.3), lineWidth: 1).padding(3))
                )
            Text("Defeated")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
            Text("Your hero falls. The monsters remain in your library.")
                .font(.callout).foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                summaryRow(label: "Photos purged", value: "\(combat.sessionPhotosDeleted)", tint: .questAmber)
                summaryRow(label: "Videos purged", value: "\(combat.sessionVideosDeleted)", tint: .videoSapphire)
                summaryRow(label: "Storage freed", value: ByteCountFormatter.string(fromByteCount: combat.sessionBytesFreed, countStyle: .file), tint: .gemEmerald)
                summaryRow(label: "XP earned", value: "+\(combat.sessionXP)", tint: .questAmber)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1)))
            .padding(.horizontal, 24)

            if let hero = heroes.first, hero.gems >= CombatViewModel.rallyCostGems {
                Button {
                    combat.rally(hero: hero, context: modelContext)
                } label: {
                    Label("Rally for \(CombatViewModel.rallyCostGems) Gems", systemImage: "diamond.fill")
                        .font(.dungeonHeader)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.questAmber))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmberDeep, lineWidth: 1))
                        .foregroundStyle(.dungeonVoid)
                }
                .padding(.horizontal, 24)
                .accessibilityHint("Spend gems to fully heal and resume the room")
            }

            Button("Return to Library") {
                exit()
            }
            .font(.headline)
            .padding(.vertical, 14).padding(.horizontal, 28)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1)))
            .foregroundStyle(.textPrimary)
        }
        .padding()
    }

    private func summaryRow(label: String, value: String, tint: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.textSecondary)
            Spacer()
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48)).foregroundStyle(.combatCrimson)
            Text("Something went wrong").font(.dungeonHeader).foregroundStyle(.textPrimary)
            Text(msg).font(.callout).foregroundStyle(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
            Button("Back to Library") { exit() }
                .padding(.vertical, 12).padding(.horizontal, 22)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1)))
                .foregroundStyle(.textPrimary)
        }
    }

    private func shake() {
        withAnimation(.linear(duration: 0.05)) { shakeOffset = -8 }
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.linear(duration: 0.05)) { shakeOffset = 8 }
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shakeOffset = 0 }
        }
    }

    private func exit() {
        try? modelContext.save()
        combat.endSessionActivity()
        appState.combatRequested = false
        dismiss()
    }
}
