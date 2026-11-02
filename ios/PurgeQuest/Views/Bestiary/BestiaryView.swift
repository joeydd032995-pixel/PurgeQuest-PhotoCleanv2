//
//  BestiaryView.swift
//  PurgeQuest
//
//  The Bestiary tab: six family tiles (FamilyTileView) lead to per-family pages where every
//  monster shows silhouette, rarity, lore, unlockable title, encounter stats,
//  and its explainable "why". Locked monsters appear as silhouettes until
//  first encountered.
//

import SwiftUI
import SwiftData

struct BestiaryView: View {
    @Query private var sightings: [MonsterSightingRecord]

    private var discoveredCount: Int {
        sightings.filter { $0.encounteredCount > 0 }.count
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    /// The family of the latest encounter, or the first family before any.
    private var spotlightFamily: MonsterFamily {
        var met: [(family: MonsterFamily, at: Date)] = []
        for record in sightings where record.encounteredCount > 0 {
            if let type = record.monsterType {
                met.append((family: type.family, at: record.lastEncounteredAt))
            }
        }
        return MonsterFamily.spotlight(latestEncounters: met)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(MonsterFamily.allCases, id: \.rawValue) { family in
                        NavigationLink(value: family) {
                            FamilyTileView(
                                family: family,
                                discovered: discoveredIn(family),
                                total: totalIn(family),
                                isSpotlight: family == spotlightFamily
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .navigationDestination(for: MonsterFamily.self) { family in
            FamilyDetailView(family: family)
        }
    }

    private var header: some View {
        BestiaryHeaderView(discovered: discoveredCount, total: MonsterType.allCases.count)
    }

    private func types(in family: MonsterFamily) -> [MonsterType] {
        MonsterType.allCases.filter { $0.family == family }
    }

    private func totalIn(_ family: MonsterFamily) -> Int {
        types(in: family).count
    }

    private func discoveredIn(_ family: MonsterFamily) -> Int {
        let discovered = Set(sightings.filter { $0.encounteredCount > 0 }.compactMap(\.monsterType))
        return types(in: family).filter { discovered.contains($0) }.count
    }
}

/// Engraved title with a short gold rule, then the discovery count.
struct BestiaryHeaderView: View {
    let discovered: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bestiary")
                .font(.dungeonScreenTitle)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Capsule()
                .fill(Color.questAmber)
                .frame(width: 56, height: 2)
            Text("\(discovered) of \(total) monsters encountered")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, 8)
    }
}
