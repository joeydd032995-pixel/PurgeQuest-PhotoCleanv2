//
//  HeroTabView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

struct HeroTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var heroes: [Hero]
    @Query private var cosmetics: [CosmeticItem]

    private var hero: Hero? { heroes.first }

    @State private var showForge: Bool = false

    /// Items currently equipped, one per wearable slot.
    private var equippedItems: [CosmeticItem] {
        cosmetics.filter { $0.isEquipped }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let hero {
                    characterCard(hero)
                    equippedSection
                    lifetimeSection(hero)
                } else {
                    Text("No hero found.")
                        .foregroundStyle(.textSecondary)
                }
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
    }

    // MARK: - Character card

    private func characterCard(_ hero: Hero) -> some View {
        VStack(spacing: 14) {
            CharacterAvatarView(hero: hero, equipped: equippedItems)

            VStack(spacing: 4) {
                Text(hero.name)
                    .font(.dungeonTitle)
                    .foregroundStyle(.textPrimary)
                Text("\(hero.archetype.displayName) · \(hero.heroClass.displayName) · LV \(hero.level)")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }

            Button {
                HapticsService.shared.light()
                showForge = true
            } label: {
                Label("Forge Hero", systemImage: "hammer.fill")
                    .font(.callout.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.questAmber.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                    )
                    .foregroundStyle(.questAmber)
            }
            .accessibilityLabel("Open the hero forge to customize your hero's look")

            XPBarView(progress: hero.levelProgress, level: hero.level)
                .padding(.horizontal, 8)

            HStack(spacing: 10) {
                GemCounterView(count: hero.gems)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.combatCrimson)
                    Text("\(hero.streakDays) day streak")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.textPrimary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.dungeonStone).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.combatCrimson.opacity(0.4), lineWidth: 1)))
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(hero.archetype == .knight ? Color.questAmber.opacity(0.5) : Color.xpViolet.opacity(0.5), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke((hero.archetype == .knight ? Color.questAmber : Color.xpViolet).opacity(0.25), lineWidth: 1).padding(2))
        )
        .fullScreenCover(isPresented: $showForge) {
            HeroForgeView(hero: hero)
        }
    }

    // MARK: - Equipped gear

    private var equippedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Equipped Gear")
                    .font(.dungeonHeader)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Button {
                    appState.selectedTab = .shop
                } label: {
                    Label("Armory", systemImage: "shield.lefthalf.filled")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.questAmber.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.questAmber.opacity(0.5), lineWidth: 1)))
                        .foregroundStyle(.questAmber)
                }
            }

            VStack(spacing: 8) {
                ForEach(CosmeticType.allCases, id: \.self) { slot in
                    gearRow(slot)
                }
            }
        }
    }

    private func gearRow(_ slot: CosmeticType) -> some View {
        let item = equippedItems.first { $0.type == slot }
        return HStack(spacing: 12) {
            Image(systemName: item?.iconName ?? "circle.dashed")
                .font(.title3.weight(.bold))
                .foregroundStyle(item != nil ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonAsh))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.dungeonStoneLight)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dungeonAsh, lineWidth: 1))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.textSecondary)
                Text(item?.name ?? "Nothing equipped")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(item != nil ? .textPrimary : .textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.dungeonAsh)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.selectedTab = .shop }
    }

    // MARK: - Lifetime stats

    private func lifetimeSection(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legend of \(hero.name)")
                .font(.dungeonHeader)
                .foregroundStyle(.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatTile(icon: "photo.fill", label: "Photos purged", value: "\(hero.totalPhotosPurged)", tint: .questAmber)
                StatTile(icon: "video.fill", label: "Videos purged", value: "\(hero.totalVideosPurged)", tint: .videoSapphire)
                StatTile(icon: "internaldrive.fill", label: "Total freed", value: formattedFreed(hero.totalMBFreed), tint: .gemEmerald)
                StatTile(icon: "bolt.fill", label: "Peak combo", value: "\(hero.highestCombo)×", tint: .combatCrimson)
            }
        }
    }

    private func formattedFreed(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024.0) }
        return String(format: "%.0f MB", mb)
    }
}
