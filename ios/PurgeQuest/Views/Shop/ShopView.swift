//
//  ShopView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData
import StoreKit

private enum ShopFilter: String, CaseIterable {
    case all = "All"
    case free = "Free"
    case video = "Video"
    case skins = "Skins"
    case head = "Head"
    case armor = "Armor"
    case weapons = "Weapons"
    case shields = "Shields"
    case pets = "Pets"
    case effects = "FX"
    case upgrades = "Upgrades"
    case bundles = "Bundles"
}

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\CosmeticItem.priceGems)]) private var cosmetics: [CosmeticItem]
    @Query private var heroes: [Hero]
    @Query private var achievements: [Achievement]

    @State private var filter: ShopFilter = .all
    @State private var purchaseError: String?
    @State private var infoMessage: String?
    @State private var isPurchasing: Bool = false
    @State private var store = StoreKitService.shared

    private var hero: Hero? { heroes.first }

    /// Whether the Titan Blade's gating achievement has been earned.
    private var titanGateUnlocked: Bool {
        achievements.first { $0.id == DyeGate.titanWeaponAchievementID }?.isUnlocked ?? false
    }

    /// Currently equipped items, one per slot — the base outfit for tile previews.
    private var equippedItems: [CosmeticItem] { cosmetics.filter { $0.isEquipped } }

    private var filtered: [CosmeticItem] {
        cosmetics.filter { c in
            switch filter {
            case .all: return true
            case .free: return c.priceGems == 0 || c.isUnlocked
            case .video: return c.isVideoThemed
            case .skins: return c.type == .skin
            case .head: return c.type == .head
            case .armor: return c.type == .armor
            case .weapons: return c.type == .weapon
            case .shields: return c.type == .shield
            case .pets: return c.type == .pet
            case .effects: return c.type == .effect
            case .upgrades: return c.type == .upgrade
            case .bundles: return false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                filterBar

                if filter == .bundles {
                    storeKitSection
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filtered) { item in
                            CosmeticTile(
                                item: item,
                                gems: hero?.gems ?? 0,
                                hero: hero,
                                equipped: equippedItems,
                                isGateLocked: item.type == .upgrade && !titanGateUnlocked
                            ) {
                                purchase(item)
                            }
                        }
                    }
                    if filter == .all { storeKitSection }
                }

                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .task { await store.loadProducts() }
        .alert("Heads up", isPresented: Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "")
        }
        .alert("Restored!", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Armory").font(.dungeonTitle).foregroundStyle(.textPrimary)
                Text("Spend storage gems on gear. Core gameplay stays free.")
                    .font(.caption).foregroundStyle(.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                GemCounterView(count: hero?.gems ?? 0)
                Button {
                    Task { await restore() }
                } label: {
                    Label("Restore", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.dungeonAsh, lineWidth: 1))
                        .foregroundStyle(.textSecondary)
                }
            }
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
                                RoundedRectangle(cornerRadius: 8).fill(filter == f ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonStone))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(filter == f ? Color.questAmberDeep : Color.dungeonAsh, lineWidth: 1))
                            )
                            .foregroundStyle(filter == f ? .dungeonVoid : .textPrimary)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    // MARK: - StoreKit section

    @ViewBuilder
    private var storeKitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "seal.fill").foregroundStyle(.questAmber)
                Text("Bundles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.textPrimary)
                Spacer()
                if store.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            Text("Optional gem packs and cosmetic bundles.")
                .font(.caption).foregroundStyle(.textSecondary)

            if store.products.isEmpty && !store.isLoading {
                Text("App Store products will appear here once your StoreKit configuration is loaded in Xcode.")
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone))
            } else {
                VStack(spacing: 10) {
                    ForEach(store.products, id: \.id) { product in
                        IAPRow(product: product, isPurchasing: isPurchasing) {
                            await buy(product)
                        }
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func purchase(_ item: CosmeticItem) {
        guard let hero else { return }

        // Permanent upgrades: ownership lives on the hero record, never in
        // the equip slots. The Titan Blade needs its achievement earned first.
        if item.type == .upgrade {
            guard !item.isUnlocked else { return }
            guard titanGateUnlocked else {
                purchaseError = "Earn the Streak Warrior achievement (7-day streak) to buy the Titan Blade."
                HapticsService.shared.warning()
                return
            }
            if hero.gems >= item.priceGems {
                hero.gems -= item.priceGems
                item.isUnlocked = true
                hero.titanWeaponUnlocked = true
                HapticsService.shared.comboBurst()
            } else {
                purchaseError = "You need \(item.priceGems - hero.gems) more gems."
                HapticsService.shared.warning()
            }
            try? modelContext.save()
            return
        }

        if item.isUnlocked {
            for c in cosmetics where c.type == item.type { c.isEquipped = false }
            item.isEquipped = true
            if item.type == .skin { hero.equippedSkinID = item.id }
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

    private func buy(_ product: Product) async {
        guard let hero else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        let success = await store.purchase(product, applyGems: { gems in
            hero.gems += gems
            try? modelContext.save()
            HapticsService.shared.comboBurst()
        }, unlockCosmetics: { ids in
            for id in ids {
                if let target = cosmetics.first(where: { $0.id == id }) {
                    target.isUnlocked = true
                }
            }
            try? modelContext.save()
            HapticsService.shared.success()
        })
        if !success, let err = store.lastError {
            purchaseError = err
        }
    }

    private func restore() async {
        await store.restore()
        // Re-apply non-consumable cosmetic entitlements to local catalog.
        for raw in store.entitledProductIDs {
            guard let pid = StoreKitService.ProductID(rawValue: raw) else { continue }
            for cid in pid.unlocksCosmeticIDs {
                if let item = cosmetics.first(where: { $0.id == cid }) {
                    item.isUnlocked = true
                }
            }
        }
        try? modelContext.save()
        infoMessage = store.entitledProductIDs.isEmpty
            ? "No previous purchases were found on this Apple ID."
            : "Your previous purchases are unlocked."
    }
}

// MARK: - StoreKit row

private struct IAPRow: View {
    let product: Product
    let isPurchasing: Bool
    let onBuy: () async -> Void

    @State private var working: Bool = false

    private var isConsumable: Bool { product.type == .consumable }

    private var symbol: String {
        if product.id.contains("gems") { return "diamond.fill" }
        if product.id.contains("videoSlayer") { return "film.stack.fill" }
        if product.id.contains("aurora") { return "moon.haze.fill" }
        if product.id.contains("embers") { return "flame.fill" }
        return "seal.fill"
    }

    private var accent: Color {
        isConsumable ? .gemEmerald : .questAmber
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dungeonStoneLight)
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 52, height: 52)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                guard !working else { return }
                Task {
                    working = true
                    await onBuy()
                    working = false
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent)
                    if working || isPurchasing {
                        ProgressView().tint(.dungeonVoid)
                    } else {
                        Text(product.displayPrice)
                            .font(.callout.weight(.heavy))
                            .foregroundStyle(.dungeonVoid)
                            .monospacedDigit()
                    }
                }
                .frame(width: 88, height: 36)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.6), lineWidth: 1))
            }
            .disabled(working || isPurchasing)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }
}

private struct CosmeticTile: View {
    let item: CosmeticItem
    let gems: Int
    let hero: Hero?
    let equipped: [CosmeticItem]
    var isGateLocked: Bool = false
    let onTap: () -> Void

    /// Whether the mini avatar renders this slot; effects and upgrades aren't drawn on the figure.
    private var isWearable: Bool {
        switch item.type {
        case .skin, .head, .armor, .weapon, .shield, .pet: return true
        case .effect, .upgrade: return false
        }
    }

    /// The avatar's outfit with this tile's item swapped into its slot.
    private var previewEquipped: [CosmeticItem] {
        equipped.filter { $0.type != item.type } + [item]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                photoStage
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(item.isEquipped ? Color.gemEmerald.opacity(0.7) : Color.dungeonAsh, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(item.isEquipped ? Color.gemEmerald.opacity(0.35) : Color.dungeonAsh.opacity(0.5), lineWidth: 1)
                            .padding(2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Photo stage

    /// Wearable slots show a live mini-avatar preview wearing the item;
    /// non-wearable slots keep the large symbol on the stone backdrop.
    private var photoStage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.dungeonStoneLight)
            .frame(height: 110)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dungeonAsh, lineWidth: 1)
            )
            .overlay {
                if let hero, isWearable {
                    MiniAvatarView(hero: hero, equipped: previewEquipped, size: 150, isAnimated: false)
                        .frame(width: 88, height: 104)
                        .clipped()
                } else {
                    Image(systemName: item.iconName)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(item.isVideoThemed ? AnyShapeStyle(Color.videoSapphire) : AnyShapeStyle(Color.questAmber))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .overlay(alignment: .topTrailing) {
                if item.isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.gemEmerald)
                        .padding(8)
                }
            }
    }

    @ViewBuilder
    private var priceTag: some View {
        if item.type == .upgrade {
            if item.isUnlocked {
                Label("Owned", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.gemEmerald.opacity(0.18)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
                    .foregroundStyle(.gemEmerald)
            } else if isGateLocked {
                Label(DyeGate.requirementText(for: DyeGate.titanWeaponAchievementID), systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.dungeonStoneLight).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dungeonAsh, lineWidth: 1)))
                    .foregroundStyle(.textSecondary)
            } else {
                priceChip
            }
        } else if item.isEquipped {
            Label("Equipped", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gemEmerald.opacity(0.18)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
                .foregroundStyle(.gemEmerald)
        } else if item.isUnlocked {
            Text("Tap to equip")
                .font(.caption.weight(.bold))
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.questAmber.opacity(0.18)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.questAmber.opacity(0.5), lineWidth: 1)))
                .foregroundStyle(.questAmber)
        } else {
            priceChip
        }
    }

    private var priceChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill").font(.caption2)
            Text("\(item.priceGems)").font(.caption.monospacedDigit().weight(.bold))
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(gems >= item.priceGems ? Color.gemEmerald.opacity(0.18) : Color.dungeonStoneLight).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
        .foregroundStyle(gems >= item.priceGems ? .gemEmerald : .textSecondary)
    }
}
