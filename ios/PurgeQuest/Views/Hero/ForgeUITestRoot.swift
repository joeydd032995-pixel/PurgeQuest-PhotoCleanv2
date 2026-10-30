//
//  ForgeUITestRoot.swift
//  PurgeQuest
//
//  DEBUG-only launch target for Forge UI tests (`-UITestForge`): an in-memory store with a seeded hero and
//  owned gear, the Forge presented immediately, and a summary label the tests read after the Forge closes.
//  `-UITestFailSave` makes persisting throw so the save-failure path can be exercised end to end.
//

#if DEBUG
import SwiftUI
import SwiftData

struct ForgeUITestRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var heroes: [Hero]
    @Query private var cosmetics: [CosmeticItem]
    @State private var showForge = false

    private struct SimulatedDiskFailure: LocalizedError {
        var errorDescription: String? { "Simulated disk failure." }
    }

    private var failSave: Bool { CommandLine.arguments.contains("-UITestFailSave") }

    private func equippedID(_ type: CosmeticType) -> String {
        cosmetics.first { $0.type == type && $0.isEquipped }?.id ?? "none"
    }

    private var summary: String {
        "weapon=\(equippedID(.weapon))|shield=\(equippedID(.shield))|head=\(equippedID(.head))"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(summary)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("forge.summary")
                Button("Open Forge") { showForge = true }
                    .accessibilityIdentifier("forge.open")
            }
        }
        .fullScreenCover(isPresented: $showForge) {
            if let hero = heroes.first {
                HeroForgeView(hero: hero, persistOverride: failSave ? { throw SimulatedDiskFailure() } : nil)
            }
        }
        .task {
            let hero = GameDataService.loadOrCreateHero(in: modelContext)
            GameDataService.seedCosmeticsIfNeeded(in: modelContext)
            _ = hero
            for item in (try? modelContext.fetch(FetchDescriptor<CosmeticItem>())) ?? [] {
                if ["weapon.shard", "weapon.staff.1.1", "shield.set.1.1", "head.starhat"].contains(item.id) { item.isUnlocked = true }
                if item.id == "weapon.shard" { item.isEquipped = true }
            }
            try? modelContext.save()
            showForge = true
        }
    }
}
#endif
