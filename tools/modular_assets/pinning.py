"""Content pinning: the one definition of an asset's content hash, and of whether an approval still matches it.

An approval in `docs/modular/approvals.json` is a statement about pixels somebody looked at. It only stays true while
those pixels stay the same, so every record stores the hash of what was approved and is honoured only while the asset
still hashes to it. Both users import it from here:

  * `approvals.py` stores the full digest in each record and stamps `verified` only from records that still match;
  * `validate.py` rejects a manifest that is `verified` on the strength of a record that no longer matches.

This is deliberately not the `#xxxxxxxx` stamp `inventory.py` prints. That one tracks which files a pass of the
pipeline regenerated, so for held gear drawn by the art packs it leaves the sprite out and hashes only the masks. An
approval is of how the thing looks, so the pin always includes the image.

What is hashed
  part-level record   the asset's image resource and every mask resource: file name then file bytes, in file-name order.
  profile record      the same files, then the canonical JSON of that profile's fit data (`fit_data`), so regenerated
                      pixels *or* a changed fit strand the fit approval.

Pure functions only: nothing here reads the ledger or the manifests from a fixed path, so callers (and tests) decide
which files are in play.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Dict, Iterable, List, Optional

REPO = Path(__file__).resolve().parents[2]
ART = REPO / "ios" / "PurgeQuest" / "Art"

SCHEMA_VERSION = 2
CURRENT, STALE, UNKNOWN = "current", "stale", "unknown-asset"
_HEX64 = re.compile(r"[0-9a-f]{64}")
_FIT_MARK = b"\x00fit\x00"      # separates the file stream from the fit data; a file name cannot contain NUL


# ---------------------------------------------------------------- files

def png_index(art: Path = ART) -> Dict[str, Path]:
    """{bundle name: path}. Bundle names are globally unique: Xcode flattens the Art folder into the bundle root."""
    return {p.stem: p for p in art.rglob("*.png")}


def resource_names(entry: dict) -> List[str]:
    """The bundle names a reviewer approves for one manifest entry: its image first, then its masks.
    Race parts name their image `resourceBaseName`, gear items `resourceName`."""
    image = entry.get("resourceBaseName") or entry["resourceName"]
    return [image, *entry.get("maskResources", {}).values()]


def asset_files(entry: dict, index: Dict[str, Path]) -> List[Path]:
    return [index[n] for n in resource_names(entry) if n in index]


def missing_resources(entry: dict, index: Dict[str, Path]) -> List[str]:
    return [n for n in resource_names(entry) if n not in index]


# ---------------------------------------------------------------- hashes

def _stream(paths: Iterable[Path]) -> "hashlib._Hash":
    h = hashlib.sha256()
    for p in sorted(paths, key=lambda q: q.name):
        h.update(p.name.encode())
        h.update(p.read_bytes())
    return h


def digest(paths: Iterable[Path]) -> str:
    """Full SHA-256 hex digest of a set of files (name, then bytes, in name order)."""
    return _stream(paths).hexdigest()


def canonical_json(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def fit_data(entry: dict, profile: str) -> dict:
    """What a per-profile fit approval approves besides the pixels: which profile, measured from which reference
    profile, whether the layer is native / adapted / unsupported there, and the scale and offset the renderer applies
    (`profileOverrides[profile]`; None where the manifest stores none)."""
    if profile in entry.get("nativeProfiles", []):
        level = "native"
    elif profile in entry.get("adaptedProfiles", []):
        level = "adapted"
    else:
        level = "unsupported"
    return {"profile": profile, "referenceProfile": entry.get("referenceProfile"), "level": level,
            "override": entry.get("profileOverrides", {}).get(profile)}


def content_hash(entry: dict, index: Dict[str, Path], profile: Optional[str] = None) -> str:
    """The hash an approval of `entry` pins: its files, plus the fit data when the approval is for a body profile."""
    h = _stream(asset_files(entry, index))
    if profile:
        h.update(_FIT_MARK)
        h.update(canonical_json(fit_data(entry, profile)).encode())
    return h.hexdigest()


def wellformed_hash(value) -> bool:
    return isinstance(value, str) and _HEX64.fullmatch(value) is not None


# ---------------------------------------------------------------- ledger records

def automated_pass(entry: dict) -> bool:
    """Whether the automated checks passed. Generators write `status` candidate/mapped; `approvals.py apply` (and
    `held_gear.py --masks-only`) keep the answer in `automatedPass` so it survives a `verified` stamp."""
    ver = entry["verification"]
    return bool(ver.get("automatedPass", ver["status"] in ("candidate", "verified")))


def evaluate(ledger: dict, entries: Iterable[dict], index: Dict[str, Path]) -> dict:
    """Decide which ledger records still count.

    A record is `current` when its `contentHash` equals the asset's hash now, `stale` when the hash is missing
    (schema 1) or different, and `unknown-asset` when no manifest entry has that id. Returns
      records   [{record, state, reason, currentHash}] in ledger order
      part      {assetId: [current part-level records]}
      profiles  {assetId: {profile: [current profile records]}}
      stale     the stale records, in ledger order
      unknown   the records naming an asset no manifest has
    Hashes are computed only for assets the ledger names, so an empty ledger costs nothing.
    """
    by_id = {e["id"]: e for e in entries}
    cache: Dict[tuple, str] = {}
    out = {"records": [], "part": {}, "profiles": {}, "stale": [], "unknown": []}
    for rec in ledger.get("approvals", []):
        asset, profile = rec.get("assetId"), rec.get("profile") or None
        entry = by_id.get(asset)
        info = {"record": rec, "state": UNKNOWN, "reason": "no such asset in the manifests", "currentHash": None}
        if entry is not None:
            key = (asset, profile)
            if key not in cache:
                cache[key] = content_hash(entry, index, profile)
            now = cache[key]
            info["currentHash"] = now
            recorded = rec.get("contentHash")
            if recorded == now:
                info["state"], info["reason"] = CURRENT, ""
            elif not recorded:
                info["state"], info["reason"] = STALE, "no content hash (recorded before approvals were pinned to content)"
            else:
                what = "the asset or its fit" if profile else "the asset"
                info["state"] = STALE
                info["reason"] = f"{what} changed after approval (approved #{str(recorded)[:8]}, now #{now[:8]})"
        out["records"].append(info)
        if info["state"] == CURRENT:
            if profile:
                out["profiles"].setdefault(asset, {}).setdefault(profile, []).append(rec)
            else:
                out["part"].setdefault(asset, []).append(rec)
        elif info["state"] == STALE:
            out["stale"].append(info)
        else:
            out["unknown"].append(info)
    return out


def stamp(entry: dict, view: dict) -> dict:
    """The verification fields `approvals.py apply` writes for one manifest entry, given `evaluate`'s view of the ledger.

    `verified` needs the automated checks to have passed *and* a current part-level record. Profile records count only
    alongside one: a fit approval is an approval of the same layer at another scale, so it means nothing while the
    layer itself is unapproved.
    """
    asset = entry["id"]
    passed = automated_pass(entry)
    part = view["part"].get(asset, [])
    profiles = view["profiles"].get(asset, {})
    if passed and part:
        reviewers = {r["reviewer"] for r in part} | {r["reviewer"] for recs in profiles.values() for r in recs}
        return {"automatedPass": passed, "status": "verified", "approvedBy": sorted(reviewers),
                "approvedProfiles": sorted(profiles)}
    return {"automatedPass": passed, "status": "candidate" if passed else "mapped", "approvedBy": None,
            "approvedProfiles": []}


def describe(rec: dict) -> str:
    """One ledger record, for a report line: asset id, profile, reviewer, date."""
    profile = f" [{rec['profile']} fit]" if rec.get("profile") else ""
    return f"{rec.get('assetId')}{profile}: approved by {rec.get('reviewer')!r} on {rec.get('date')}"
