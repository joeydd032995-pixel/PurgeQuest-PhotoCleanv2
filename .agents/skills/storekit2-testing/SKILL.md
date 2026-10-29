---
name: storekit2-testing
description: Implement and test StoreKit 2 purchases with local Configuration.storekit files for offline SwiftUI apps. Use when adding gem packs, cosmetic bundles, consumables, non-consumables, paywalls, transaction listeners, restore purchases, or verifying purchases without App Store Connect products yet.
---

# Skill: StoreKit 2 + Local .storekit Testing

## Goal
Ship correct StoreKit 2 purchase flows (consumable gems and non-consumable cosmetics) that work in the Xcode simulator and on device using a local Configuration.storekit file, while keeping core gameplay free and offline.

## Trigger
Use when the task involves StoreKitService, Configuration.storekit, Product.purchase, Transaction.updates, gem packs, cosmetic bundles, restore purchases, or local IAP testing without live App Store Connect records.

## Inputs
- Existing StoreKitService (or equivalent)
- Configuration.storekit path and product IDs
- Catalog of CosmeticItem / gem economy in GameDataService
- Entitlements and scheme StoreKit configuration setting

## Process
1. Define products only as cosmetic or consumable currency. Never gate core combat or deletion behind paywalls.
2. Keep product IDs identical between Configuration.storekit and the code that looks them up.
3. Use StoreKit 2 async APIs (Product.products, product.purchase, Transaction.currentEntitlements, Transaction.updates).
4. Listen for Transaction.updates at app launch. Apply verified transactions durably and idempotently before finishing them; handle recovery and revocations appropriately.
5. For local testing, select the .storekit file in the Xcode scheme under Run > Options > StoreKit Configuration.
6. Grant gems or unlock cosmetics only after a verified Transaction; never on button tap alone.
7. Provide a restore path that re-applies non-consumable ownership from currentEntitlements.
8. Handle user cancellation, pending, and failed states with clear UI feedback and no double-grants.

## Tools
- StoreKit 2 (StoreKit framework)
- Local Configuration.storekit for sandbox-free testing
- Swift Testing or manual checklist for purchase and restore paths
- No RevenueCat or third-party IAP wrappers unless the user explicitly requests them

## Output
- Working purchase and restore code
- Matching product IDs in .storekit and source
- Scheme note reminding the tester to select the StoreKit configuration
- Confirmation that core loop remains free

## Quality checks
- Purchase grants the expected gems or ownership exactly once
- Restore re-applies non-consumables without duplicating consumables
- Cancelled purchase leaves state unchanged
- Local testing uses the StoreKit configuration; production purchases use Apple services

## Failure handling
- Missing product ID returns a clear error instead of silent failure
- Unverified or revoked transactions are never granted
- If the .storekit file is not selected in the scheme, document the exact Xcode steps

## Metrics
- Local purchase succeeds end-to-end with the scheme config
- Transaction listener finishes every transaction
- Agent can list every product ID and its type (consumable vs non-consumable)
