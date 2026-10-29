---
name: coreml-model-swap
description: Introduce on-device Core ML models into PurgeQuest's media analysis pipeline while preserving existing classification behavior and heuristic fallbacks. Use when adding or evaluating Core ML models, swapping heuristics, or improving photo and video analysis.
---

# Skill: Core ML Model Swap

## What this is
PurgeQuest currently extracts signals using heuristics such as Laplacian variance, average luminance, Photos subtype flags, and dHash. `MonsterClassifier` is a static enum over media and fingerprint signals; `MLAnalysisService` and other services extract them. There are currently no `PhotoClassifier` or `VideoClassifier` protocols. Inspect the current pipeline before choosing an integration seam.

A **Core ML model swap** means:
- Train or obtain a Core ML model (.mlmodel / .mlpackage) that answers the same questions more accurately.
- Drop the model into the Xcode project.
- Integrate the model at an appropriate signal-extraction seam, adding a protocol only if the change benefits from one.
- Keep the old heuristic implementation as a fallback when the model is missing, fails to load, or runs on an unsupported device.
- Preserve existing classification and review behavior; change call sites only as needed for the chosen seam.

Preserve the game loop and deletion safety. Inference should be on device; Photos may still download iCloud media, and StoreKit uses Apple services.

## Goal
Introduce real Core ML models at a suitable boundary so classification accuracy can improve while heuristics remain available as fallbacks.

## Trigger
Use when the task mentions Core ML, .mlmodel, BlurClassifier, VideoQualityScorer, model swap, replace heuristics, Vision + Core ML, or improving classification accuracy without changing call sites.

## Inputs
- Existing signal extraction and classification boundaries; a protocol may need to be introduced if warranted
- Current heuristic implementation (MLAnalysisService, etc.)
- Model file(s) or Create ML / training plan
- Target device set (A12+ recommended for Neural Engine)

## Process
1. Inspect the current signal and classifier boundaries. Introduce a small testable abstraction only if it is useful for the model and fallback.
2. Add the .mlmodel / .mlpackage to the app target and let Xcode generate the Swift model class.
3. Run the model on an appropriately prepared thumbnail or short frame set behind the selected boundary.
4. Keep the existing heuristic path as a fallback when the model is unavailable or fails.
5. Run inference off the main actor when possible; return results to the UI on the main actor.
6. Bound memory and time — reuse the same downsampling path the heuristics already use.
7. Add unit or integration tests that feed known images and assert the model path produces expected labels when the model is present.
8. Document the model version, input size, and expected accuracy vs the old heuristic thresholds.

## Tools
- Core ML + Vision (VNCoreMLRequest when useful)
- Create ML or an external trained .mlmodel
- Existing downsample / thumbnail pipeline
- Existing analysis/classification boundaries; see the example in `references/swap-pattern.md` for a possible future protocol

## Output
- Core ML-backed signal extraction or classification integrated at the chosen boundary
- Explicit fallback to heuristics
- Explain any required call-site changes
- Short note on model size, input shape, and how to retrain later

## Quality checks
- App still runs and classifies when the model file is removed (fallback works)
- Inference stays on-device, without remote analysis
- Classification remains explainable (signalDescription / lore still make sense)
- Memory spikes stay within the same order of magnitude as the heuristic path

## Failure handling
- Model load failure or unsupported compute unit falls back to heuristics with a single debug log
- Invalid or empty input image returns the same safe default the heuristic path used
- If the model output schema changes, adapt only the new concrete type; do not break the protocol

## Metrics
- Measurable accuracy on a held-out set of library photos, compared with the heuristic baseline
- Zero call-site changes outside the classifier factory
- On-device inference and recoverable-deletion contracts remain intact
