---
name: purgequest-media-classifier
description: Implement and harden on-device photo and video classification, duplicate detection, and bestiary mapping for PurgeQuest-style media-cleanup RPGs. Use when working on MLAnalysisService, MonsterClassifier, DuplicateDetection, dHash, content hashing, Vision signals, blur detection, luminance, monster types, unreachable quests or achievements, or expanding the monster roster and quest reachability.
---

# Skill: PurgeQuest Media Classifier & Duplicate Engine

## Goal
Deliver accurate, explainable, on-device classification of PHAssets into MonsterTypes, plus reliable duplicate clustering, without adding remote analysis or permanent deletion, and with clear player-facing review guidance. Photos may download iCloud-backed media.

## Trigger
Use when the task involves blur/luminance heuristics, perceptual hashing, content hashes, MonsterType assignment, DuplicateCluster logic, bestiary families, or quests/achievements that reference specific monsters.

## Inputs
- Current Services (MLAnalysisService, MonsterClassifier, DuplicateDetection, VisionAnalysisService, MediaFingerprintStore)
- MonsterType enum and family/rarity definitions
- Quest / achievement / seasonal references that name monster IDs
- Sample asset characteristics (duration, size, subtype flags, age)

## Process
1. Keep signal extraction (sharpness, luminance, dHash, content hash) separate from classification decisions.
2. Classification must be pure or easily mockable over MediaFingerprint / MediaItem so unit tests can cover every MonsterType.
3. Duplicate pipeline stages
   - Stage A exact (content hash or strong metadata equality)
   - Stage B near (dHash Hamming distance + time proximity for burst/edited/echo kinds)
4. Survivor ranking is a suggestion only; the player always confirms.
5. Every MonsterType that appears in quests, achievements, or seasonal bonuses must be reachable by the classifier. Audit and fix unreachable types.
6. Preserve the existing signal-extraction and classification boundaries. `MonsterClassifier` is currently a static enum and the named PhotoClassifier / VideoClassifier protocols are absent; add an abstraction only when useful for a concrete model integration.
7. Document reviewGuidance and defaultsToCarefulReview for sensitive types (ancient, glitch, codes, live photo pairs).

## Tools
- CoreImage / Vision for local analysis
- Photos framework metadata and subtype flags
- Swift Testing for pure clustering and threshold tests
- No remote ML or cloud vision

## Output
- Updated classifier or detection code
- Test coverage for new or previously unreachable types
- Explicit mapping of signal to MonsterType to family to XP/HP
- Note of any remaining unreachable content

## Quality checks
- No MonsterType referenced by game content is permanently unreachable
- Hamming and exact paths are deterministic and order-independent where required
- Memory and CPU stay bounded for large libraries (downsample, cache fingerprints)
- Careful-review types never auto-delete

## Failure handling
- Missing thumbnail or unreadable asset maps to safe fallback type with careful-review flag
- If a new signal is expensive, gate it behind existing fingerprint cache
- If Core ML models are added later, keep the heuristic path as fallback

## Metrics
- All referenced monsters reachable
- Unit tests pass for clustering edge cases (exact, burst, edited, hoard size)
- Classification remains explainable to the player via signalDescription and lore
