//
//  ShopView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

private enum ShopFilter: String, CaseIterable {
    case all = "All"
    case free = "Free"
    case video = "Video"
    case skins = "Skins"
    case effects = "FX"
}

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\CosmeticItem.priceGems)]) private var cosmetics: [CosmeticItem]
    @Query private var heroes: [Hero]

    @State private var filter: ShopFilter = .all
    @State private var purchaseError: String?

    private var hero: Hero? { heroes.first }

    private var filtered: [CosmeticItem] {
        cosmetics.filter { c in
            switch filter {
            case .all: return true
            case .free: return c.priceGems == 0 || c.isUnlocked
            case .video: return c.isVideoThemed
            case .skins: return c.type == .skin
            case .effects: return c.type == .effect
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                filterBar
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(filtered) { item in
                        CosmeticTile(item: item, gems: hero?.gems ?? 0) {
                            purchase(item)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .alert("Not enough gems", isPresented: Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cosmetics Shop").font(.title.weight(.bold)).foregroundStyle(.textPrimary)
                Text("Spend Storage Gems on flair. Gameplay always free.").font(.caption).foregroundStyle(.textSecondary)
            }
            Spacer()
            GemCounterView(count: hero?.gems ?? 0)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { filter = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                Capsule().fill(filter == f ? AnyShapeStyle(LinearGradient.amberGlow) : AnyShapeStyle(Color.dungeonStone))
                                    .overlay(Capsule().stroke(filter == f ? Color.clear : Color.dungeonAsh, lineWidth: 1))
                            )
                            .foregroundStyle(filter == f ? .dungeonVoid : .textPrimary)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private func purchase(_ item: CosmeticItem) {
        guard let hero else { return }
        if item.isUnlocked {
            // Equip / unequip toggling
            for c in cosmetics where c.type == item.type { c.isEquipped = false }
            item.isEquipped = true
            hero.equippedSkinID = item.id
            HapticsService.shared.success()
        } else {
            if hero.gems >= item.priceGems {
                hero.gems -= item.priceGems
                item.isUnlocked = true
                HapticsService.shared.comboBurst()
            } else {
                purchaseError = "You need \(item.priceGems - hero.gems) more gems."
                HapticsService.shared.warning()
            }
        }
        try? modelContext.save()
    }
}

private struct CosmeticTile: View {
    let item: CosmeticItem
    let gems: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.dungeonStoneLight, .dungeonStone], startPoint: .top, endPoint: .bottom))
                        .frame(height: 110)
                    Image(systemName: item.iconName)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(item.isVideoThemed ? AnyShapeStyle(Color.videoSapphire) : AnyShapeStyle(LinearGradient.amberGlow))
                        .symbolRenderingMode(.hierarchical)
                    if item.isEquipped {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.gemEmerald)
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                Text(item.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)

                priceTag
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dungeonStone)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(item.isEquipped ? Color.gemEmerald.opacity(0.7) : Color.dungeonAsh, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var priceTag: some View {
        if item.isEquipped {
            Label("Equipped", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Capsule().fill(Color.gemEmerald.opacity(0.18)).overlay(Capsule().stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
                .foregroundStyle(.gemEmerald)
        } else if item.isUnlocked {
            Text("Tap to equip")
                .font(.caption.weight(.bold))
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Capsule().fill(Color.questAmber.opacity(0.18)).overlay(Capsule().stroke(Color.questAmber.opacity(0.5), lineWidth: 1)))
                .foregroundStyle(.questAmber)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill").font(.caption2)
                Text("\(item.priceGems)").font(.caption.monospacedDigit().weight(.bold))
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(Capsule().fill(gems >= item.priceGems ? Color.gemEmerald.opacity(0.18) : Color.dungeonStoneLight).overlay(Capsule().stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
            .foregroundStyle(gems >= item.priceGems ? .gemEmerald : .textSecondary)
        }
    }
}
