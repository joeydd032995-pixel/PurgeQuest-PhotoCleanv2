//
//  BestiaryView.swift
//  PurgeQuest
//
//  The Bestiary tab: six family tiles lead to per-family pages where every
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

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bestiary")
                        .font(.dungeonTitle)
                        .foregroundStyle(.textPrimary)
                    Text("\(discoveredCount) of \(MonsterType.allCases.count) monsters encountered")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(MonsterFamily.allCases, id: \.rawValue) { family in
                        NavigationLink(value: family) {
                            FamilyTile(family: family, discovered: discoveredIn(family), total: totalIn(family))
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

/// Family tile on the Bestiary grid.
private struct FamilyTile: View {
    let family: MonsterFamily
    let discovered: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: family.symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(family.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(family.displayName)
                .font(.dungeonCaption.weight(.bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Text(family.tagline)
                .font(.caption2)
                .foregroundStyle(.textSecondary)
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .top)
            Text("\(discovered) / \(total) found")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(discovered > 0 ? family.accentColor : .textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(family.accentColor.opacity(0.4), lineWidth: 1))
        )
    }
}
