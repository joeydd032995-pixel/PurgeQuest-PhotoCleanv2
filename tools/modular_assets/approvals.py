"""Human-approval ledger for modular assets.

`docs/modular/approvals.json` is the only way an asset becomes `verified`. Each record names
the asset, the reviewer, and (for body-profile fits) the profile approved. `apply()` re-stamps
both bundled manifests from the ledger; `approve.py`-style CLI usage:

    python3 tools/modular_assets/approvals.py approve valkyrie_v1 --reviewer "Name" [--profile standard] [--note "..."]
    python3 tools/modular_assets/approvals.py apply
"""
from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LEDGER = REPO / "docs" / "modular" / "approvals.json"
RACES = REPO / "ios" / "PurgeQuest" / "Art" / "Modular" / "modular_races_manifest.json"
GEAR = REPO / "ios" / "PurgeQuest" / "Art" / "Modular" / "modular_gear_manifest.json"


def load_ledger() -> dict:
    if LEDGER.exists():
        return json.loads(LEDGER.read_text())
    return {"schemaVersion": 1, "approvals": []}


def _automated_ok(entry: dict) -> bool:
    return entry["verification"]["status"] in ("candidate", "verified")


def apply(write: bool = True) -> dict:
    """Stamp `verified` / approvedProfiles onto manifest entries from the ledger. Returns counts."""
    ledger = load_ledger()
    by_asset: dict = {}
    for rec in ledger["approvals"]:
        by_asset.setdefault(rec["assetId"], []).append(rec)
    counts = {"verified": 0, "candidate": 0, "mapped": 0}
    for path, key in ((RACES, "parts"), (GEAR, "items")):
        manifest = json.loads(path.read_text())
        for entry in manifest[key]:
            recs = by_asset.get(entry["id"], [])
            profiles = sorted({r["profile"] for r in recs if r.get("profile")})
            part_level = any(not r.get("profile") for r in recs)
            ver = entry["verification"]
            automated_pass = ver.get("automatedPass", ver["status"] in ("candidate", "verified"))
            ver["automatedPass"] = automated_pass
            if automated_pass and part_level:
                ver["status"] = "verified"
                ver["approvedBy"] = sorted({r["reviewer"] for r in recs})
                ver["approvedProfiles"] = profiles
            else:
                ver["status"] = "candidate" if automated_pass else "mapped"
                ver["approvedBy"] = None
                ver["approvedProfiles"] = []
            counts[ver["status"]] += 1
        if write:
            path.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    return counts


def approve(prefix: str, reviewer: str, profile: str | None, note: str) -> int:
    ledger = load_ledger()
    ids = []
    for path, key in ((RACES, "parts"), (GEAR, "items")):
        ids += [e["id"] for e in json.loads(path.read_text())[key] if e["id"].startswith(prefix)]
    if not ids:
        sys.exit(f"no asset id starts with {prefix!r}")
    today = datetime.date.today().isoformat()
    existing = {(r["assetId"], r.get("profile")) for r in ledger["approvals"]}
    added = 0
    for asset in ids:
        if (asset, profile) in existing:
            continue
        ledger["approvals"].append({"assetId": asset, "profile": profile, "reviewer": reviewer, "date": today, "note": note})
        added += 1
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(ledger, indent=1) + "\n")
    return added


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("approve")
    a.add_argument("prefix")
    a.add_argument("--reviewer", required=True)
    a.add_argument("--profile")
    a.add_argument("--note", default="")
    sub.add_parser("apply")
    args = ap.parse_args()
    if args.cmd == "approve":
        print("approvals added:", approve(args.prefix, args.reviewer, args.profile, args.note))
    print(apply())


if __name__ == "__main__":
    main()
