//
//  StoreKitService.swift
//  PurgeQuest
//
//  StoreKit 2 wrapper for premium cosmetic IAPs and consumable Gem Packs.
//  All gameplay content is free; this powers cosmetic-only monetization.
//
//  To test locally without a real App Store Connect record, ship a
//  `Configuration.storekit` file alongside the project and select it
//  in the Xcode scheme. Product IDs declared here:
//
//    Non-consumable:
//      com.purgequest.cosmetic.videoSlayerBundle
//      com.purgequest.cosmetic.embers
//      com.purgequest.cosmetic.aurora
//    Consumable:
//      com.purgequest.gems.250
//      com.purgequest.gems.1000
//      com.purgequest.gems.5000
//

import Foundation
import StoreKit

@MainActor
@Observable
final class StoreKitService {
    static let shared = StoreKitService()

    enum ProductID: String, CaseIterable {
        case videoSlayerBundle = "com.purgequest.cosmetic.videoSlayerBundle"
        case embersSkin        = "com.purgequest.cosmetic.embers"
        case auroraEffect      = "com.purgequest.cosmetic.aurora"
        case gems250           = "com.purgequest.gems.250"
        case gems1000          = "com.purgequest.gems.1000"
        case gems5000          = "com.purgequest.gems.5000"

        var isConsumable: Bool {
            switch self {
            case .gems250, .gems1000, .gems5000: return true
            default: return false
            }
        }

        /// Cosmetic IDs unlocked by a non-consumable product, matched against `CosmeticItem.id`.
        var unlocksCosmeticIDs: [String] {
            switch self {
            case .embersSkin:        return ["skin.embers"]
            case .auroraEffect:      return ["fx.aurora"]
            case .videoSlayerBundle: return ["weapon.reel", "pet.reel", "fx.filmstrip"]
            default: return []
            }
        }

        var gemAmount: Int {
            switch self {
            case .gems250:  return 250
            case .gems1000: return 1000
            case .gems5000: return 5000
            default: return 0
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var entitledProductIDs: Set<String> = []
    private(set) var lastError: String?
    private(set) var isLoading: Bool = false

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
    }

    // MARK: - Loading

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = ProductID.allCases.map(\.rawValue)
            products = try await Product.products(for: ids)
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product, applyGems: ((Int) -> Void)? = nil, unlockCosmetics: (([String]) -> Void)? = nil) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await applyEntitlement(for: tx, applyGems: applyGems, unlockCosmetics: unlockCosmetics)
                await tx.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Internals

    private func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                ids.insert(tx.productID)
            }
        }
        entitledProductIDs = ids
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = result {
                    await self.applyEntitlement(for: tx, applyGems: nil, unlockCosmetics: nil)
                    await tx.finish()
                }
            }
        }
    }

    private func applyEntitlement(for tx: Transaction, applyGems: ((Int) -> Void)?, unlockCosmetics: (([String]) -> Void)?) async {
        guard let pid = ProductID(rawValue: tx.productID) else { return }
        if pid.isConsumable {
            applyGems?(pid.gemAmount)
        } else {
            entitledProductIDs.insert(tx.productID)
            unlockCosmetics?(pid.unlocksCosmeticIDs)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let err): throw err
        case .verified(let value): return value
        }
    }
}
