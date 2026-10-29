---
name: swiftdata-offline-rpg
description: Build and maintain local SwiftData-backed RPG progression systems including hero, quests, achievements, cosmetics, streaks, seasonal events, and combat session state. Use for PurgeQuest's gem economy, daily quests, StoreKit cosmetic purchases, XP curves, or class perks.
---

# Skill: SwiftData Offline RPG Progression

## Goal
Keep a complete offline progression loop correct, fair, and recoverable — XP, levels, gems, daily quests, achievements, cosmetics, streaks, and seasonal modifiers — with SwiftData as the only persistence layer.

## Trigger
Use when changing Hero model, GameDataService, Quest/Achievement seeding, CosmeticItem catalog, SeasonalEventService, CombatSession, StoreKit gem packs, or daily login / streak logic.

## Inputs
- Current SwiftData schema (Hero and related models)
- Seed data in GameDataService
- Seasonal date rules
- StoreKit product IDs and local .storekit config
- Combat reward math (combo, class perks, elite bonuses)

## Process
1. Treat SwiftData as the single source of truth. No parallel caches that can diverge permanently.
2. Seed catalogs and quests idempotently; never wipe owned cosmetics or progress on update.
3. Daily quests refresh only when expired; preserve in-progress progress where intended.
4. Seasonal events are pure local date matching — no remote config.
5. StoreKit purchases grant only cosmetics or consumable gems; core loop stays free.
6. Combat rewards apply class perks and combo multipliers deterministically from CombatViewModel / GameDataService.
7. Provide a full data-reset path in Settings that is explicit and irreversible only after confirmation.
8. Audit that every achievement and quest can actually be completed with the current classifier and systems.

## Tools
- SwiftData ModelContainer with disk + in-memory fallback
- StoreKit 2 async APIs
- Local date/time for seasonal and daily logic
- Swift Testing for XP curves, quest progress, and seed consistency

## Output
- Updated models or services that preserve existing player data
- Seed / migration notes if schema changes
- Verification that referenced cosmetic IDs and monster types exist

## Quality checks
- No silent loss of gems, ownership, or streak
- Seasonal exclusive cosmetics either exist in the catalog or the reference is removed
- Reward math is unit-testable without UI
- Privacy statements accurately describe local game state, Photos/iCloud access, and StoreKit's use of Apple services

## Failure handling
- Corrupt store falls back to in-memory and surfaces a clear recovery path
- Missing product IDs in StoreKit config are reported rather than silently failing purchases
- If a quest targets an unreachable monster, either implement the classifier path or retire the quest

## Metrics
- Progression is reproducible from the same combat outcomes
- Schema changes are additive when possible
- Agent can list the exact models in the current schema
