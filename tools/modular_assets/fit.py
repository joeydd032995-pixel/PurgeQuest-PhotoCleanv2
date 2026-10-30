"""Python mirror of ModularCharacterFoundation.swift body profiles and PartFitter.

Kept in lock-step with the Swift source; test_fit_parity in tests/ compares both
by parsing the Swift file, so drift fails the check.
"""
from __future__ import annotations

from typing import Dict, Optional, Tuple

# shoulderWidth, torsoWidth, armLength, armThickness, legLength, legThickness, headScale
PROFILES: Dict[str, Tuple[float, ...]] = {
    "slender": (0.90, 0.95, 1.02, 0.90, 1.04, 0.92, 0.96),
    "standard": (1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00),
    "athletic": (1.10, 1.04, 1.05, 1.08, 1.02, 1.05, 1.00),
    "skeletal": (0.94, 0.90, 1.00, 0.78, 1.02, 0.76, 0.98),
    "brute": (1.24, 1.16, 1.06, 1.18, 0.98, 1.16, 1.08),
}
KEYS = ("shoulderWidth", "torsoWidth", "armLength", "armThickness", "legLength", "legThickness", "headScale")

RACE_DEFAULT_PROFILE = {
    "valkyrie": "athletic", "forest_ranger": "slender", "seer": "slender", "blood_alchemist": "athletic",
    "dark_oracle": "standard", "necromancer": "slender", "skeleton_crusader": "skeletal",
    "skeleton_warrior": "skeletal", "golem": "brute",
}

DEFAULT_RANGE = (0.90, 1.10)


def metrics(profile: str) -> Dict[str, float]:
    return dict(zip(KEYS, PROFILES[profile]))


def scale_pair(slot: str, src: Dict[str, float], tgt: Dict[str, float]) -> Tuple[float, float]:
    if slot in ("head", "helmet"):
        s = tgt["headScale"] / src["headScale"]
        return s, s
    if slot in ("torso", "chestArmor", "waistArmor"):
        return tgt["torsoWidth"] / src["torsoWidth"], 1.0
    if slot in ("leftShoulder", "rightShoulder"):
        s = tgt["shoulderWidth"] / src["shoulderWidth"]
        return s, s
    if slot in ("leftArm", "rightArm", "leftGauntlet", "rightGauntlet"):
        return tgt["armThickness"] / src["armThickness"], tgt["armLength"] / src["armLength"]
    if slot in ("leftHand", "rightHand"):
        s = tgt["armThickness"] / src["armThickness"]
        return s, s
    if slot in ("leftLeg", "rightLeg", "leftLegArmor", "rightLegArmor", "leftBoot", "rightBoot"):
        return tgt["legThickness"] / src["legThickness"], tgt["legLength"] / src["legLength"]
    return 1.0, 1.0


def fit(slot: str, reference: str, target: str, rx=DEFAULT_RANGE, ry=DEFAULT_RANGE) -> Optional[Tuple[float, float]]:
    sx, sy = scale_pair(slot, metrics(reference), metrics(target))
    if rx[0] <= sx <= rx[1] and ry[0] <= sy <= ry[1]:
        return sx, sy
    return None


def compatibility(slot: str, reference: str, target: str) -> Tuple[str, Optional[Tuple[float, float]]]:
    f = fit(slot, reference, target)
    if f is None:
        return "unsupported", None
    return ("native" if target == reference else "adapted"), f
