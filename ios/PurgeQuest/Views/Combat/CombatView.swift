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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80)).foregroundStyle(.gemEmerald)
            Text("All clear, hero!")
                .font(.title.weight(.bold)).foregroundStyle(.textPrimary)
            Text("Your camera roll has no monsters to fight.\nReturn another day.")
                .font(.callout).foregroundStyle(.textSecondary).multilineTextAlignment(.center)
            Button("Back to Dashboard") {
                exit()
            }
            .padding(.vertical, 12).padding(.horizontal, 24)
            .background(Capsule().fill(LinearGradient.amberGlow))
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
                        onSpare: { combat.decideSpare(top, context: modelContext) }
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
                        .background(LinearGradient.crimsonGlow, in: Capsule())
                        .foregroundStyle(.white)
                }
                .accessibilityHint("Mark monster for deletion")

                Button { if let top = combat.topItem { combat.decideSpare(top, context: modelContext) } } label: {
                    Label("SPARE", systemImage: "shield.fill")
                        .font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient.emeraldGlow, in: Capsule())
                        .foregroundStyle(.dungeonVoid)
                }
                .accessibilityHint("Spare this monster, take damage")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 90))
                .foregroundStyle(LinearGradient.amberGlow)
                .shadow(color: .questAmber.opacity(0.6), radius: 20)
            Text("Dungeon Complete!")
                .font(.system(size: 36, weight: .black, design: .serif))
                .foregroundStyle(.textPrimary)
            VStack(spacing: 8) {
                summaryRow(label: "Photos purged", value: "\(combat.sessionPhotosDeleted)", tint: .questAmber)
                summaryRow(label: "Videos purged", value: "\(combat.sessionVideosDeleted)", tint: .videoSapphire)
                summaryRow(label: "Storage freed", value: ByteCountFormatter.string(fromByteCount: combat.sessionBytesFreed, countStyle: .file), tint: .gemEmerald)
                summaryRow(label: "XP earned", value: "+\(combat.sessionXP)", tint: .questAmberDeep)
                summaryRow(label: "Gems earned", value: "+\(combat.sessionGems)", tint: .gemEmerald)
                summaryRow(label: "Peak combo", value: "\(combat.peakCombo)×", tint: .combatCrimson)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.dungeonAsh, lineWidth: 1)))
            .padding(.horizontal, 24)

            if combat.hasMoreItems, let hero = heroes.first {
                Button {
                    combat.continueDeeper(hero: hero)
                } label: {
                    Label("Continue Deeper", systemImage: "arrow.down.to.line.compact")
                        .font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient.emeraldGlow, in: Capsule())
                        .foregroundStyle(.dungeonVoid)
                }
                .accessibilityHint("Start another run through the dungeon without returning to the dashboard")
            }

            Button("Return to Dashboard") {
                exit()
            }
            .font(.headline)
            .padding(.vertical, 14).padding(.horizontal, 28)
            .background(
                Capsule().fill(
                    combat.hasMoreItems
                        ? AnyShapeStyle(Color.dungeonStone)
                        : AnyShapeStyle(LinearGradient.amberGlow)
                )
                .overlay(Capsule().stroke(Color.dungeonAsh, lineWidth: combat.hasMoreItems ? 1 : 0))
            )
            .foregroundStyle(combat.hasMoreItems ? Color.textPrimary : Color.dungeonVoid)
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
                .font(.system(size: 60)).foregroundStyle(.combatCrimson)
            Text("Trouble in the dungeon").font(.title2.weight(.bold)).foregroundStyle(.textPrimary)
            Text(msg).font(.callout).foregroundStyle(.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
            Button("Back to Dashboard") { exit() }
                .padding(.vertical, 12).padding(.horizontal, 22)
                .background(Capsule().fill(Color.dungeonStone).overlay(Capsule().stroke(Color.dungeonAsh, lineWidth: 1)))
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
