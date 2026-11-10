"""Human-approval ledger for modular assets.

`docs/modular/approvals.json` is the only way an asset becomes `verified`. Each record names the asset, the reviewer,
the date, (for a body-profile fit) the profile, and the hash of exactly what was looked at (`pinning.content_hash`).
`apply()` re-stamps both bundled manifests from the ledger, honouring only records whose hash still matches the files.

    python3 -I tools/modular_assets/approvals.py status                                    # where review stands
    python3 -I tools/modular_assets/approvals.py approve pack:valkyrie_v1 --reviewer "Name"    # every layer of one pack
    python3 -I tools/modular_assets/approvals.py approve pack:valkyrie_v1 --reviewer "Name" --profile standard   # an adapted fit
    python3 -I tools/modular_assets/approvals.py approve group:staff1 --reviewer "Name"        # a gear group
    python3 -I tools/modular_assets/approvals.py approve id:weapon.staff --reviewer "Name"     # exactly one asset
    python3 -I tools/modular_assets/approvals.py revoke pack:valkyrie_v1 --reviewer "Name" --note "cheek mask"
    python3 -I tools/modular_assets/approvals.py apply                                     # re-stamp from the ledger

Rules
  * An approval is pinned to content. Regenerate an asset and its record goes stale: the asset drops back to
    `candidate` at the next `apply`, and the record stays in the ledger, reported, until it is revoked or the asset is
    approved again (which replaces it).
  * Only an asset whose automated checks passed can be approved; a human cannot overrule a failed check from here.
  * A fit approval (`--profile`) counts only alongside a part-level approval of the same layer, and is recorded only
    for layers that adapt to that profile. Revoking a part-level approval therefore also removes that layer's fit
    approvals; revoking with `--profile` removes just that fit.
  * Revocations are kept (`revocations` in the ledger), so the file is a history, not just a current state.

Approving is a statement by a person who looked at the sheets (`docs/modular/REVIEW.md`). Nothing in this repository
records an approval on its own.
"""
from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).parent))
import fit as fitmod  # noqa: E402
import pinning  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
LEDGER = REPO / "docs" / "modular" / "approvals.json"
RACES = REPO / "ios" / "PurgeQuest" / "Art" / "Modular" / "modular_races_manifest.json"
GEAR = REPO / "ios" / "PurgeQuest" / "Art" / "Modular" / "modular_gear_manifest.json"
ART = pinning.ART
DOC = ("Human approvals only, each pinned to the content hash of what was reviewed. "
       "Add and remove records with tools/modular_assets/approvals.py; see docs/modular/REVIEW.md.")


def load_ledger() -> dict:
    """The ledger, in the current shape. A schema-1 file (records without a hash) loads as is: its records are stale."""
    if LEDGER.exists():
        ledger = json.loads(LEDGER.read_text())
    else:
        ledger = {}
    ledger.setdefault("approvals", [])
    ledger.setdefault("revocations", [])
    return ledger


def save_ledger(ledger: dict) -> None:
    out = {"schemaVersion": pinning.SCHEMA_VERSION, "_doc": DOC, "approvals": ledger["approvals"]}
    if ledger.get("revocations"):
        out["revocations"] = ledger["revocations"]
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(out, indent=1) + "\n")


def load_manifests() -> list:
    """[(path, key, manifest)] for the races and gear manifests."""
    return [(path, key, json.loads(path.read_text())) for path, key in ((RACES, "parts"), (GEAR, "items"))]


def all_entries(manifests: list) -> List[dict]:
    return [e for _, key, m in manifests for e in m[key]]


def view_of(ledger: dict, manifests: list) -> dict:
    return pinning.evaluate(ledger, all_entries(manifests), pinning.png_index(ART))


def apply(write: bool = True) -> dict:
    """Stamp `verified` / approvedProfiles onto manifest entries from the ledger. Returns the status counts, plus the
    stale records under `stale` (a list of report lines)."""
    ledger = load_ledger()
    manifests = load_manifests()
    view = view_of(ledger, manifests)
    counts = {"verified": 0, "candidate": 0, "mapped": 0}
    for path, key, manifest in manifests:
        before = json.dumps(manifest, sort_keys=True)
        for entry in manifest[key]:
            entry["verification"].update(pinning.stamp(entry, view))
            counts[entry["verification"]["status"]] += 1
        if write and json.dumps(manifest, sort_keys=True) != before:
            path.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    counts["stale"] = [f"{pinning.describe(i['record'])}: {i['reason']}" for i in view["stale"]]
    return counts


def _matching(target: str, manifests: list) -> List[dict]:
    """The assets a command names: `pack:NAME` (every layer of an art pack), `group:NAME` (a gear group such as
    `staff1` or `store`), `id:EXACT`, or a bare id prefix. A bare target that is one asset's whole id and also the
    start of others is refused: `weapon.staff` is the Archmage Staff, and the first eleven characters of forty staves.
    """
    entries = all_entries(manifests)
    kind, _, name = target.partition(":")
    if name and kind in ("pack", "group", "id"):
        field = {"pack": "pack", "group": "group", "id": "id"}[kind]
        found = [e for e in entries if e.get(field) == name]
        if not found:
            sys.exit(f"no asset has {field} {name!r}")
        return found
    found = [e for e in entries if e["id"].startswith(target)]
    if not found:
        sys.exit(f"no asset id starts with {target!r}")
    if len(found) > 1 and any(e["id"] == target for e in found):
        sys.exit(f"{target!r} is one asset's id and also a prefix of {len(found) - 1} others; "
                 f"say id:{target} for the one, or pack:/group: for a set")
    return found


def _reviewer(name: str) -> str:
    name = (name or "").strip()
    if not name:
        sys.exit("--reviewer is required: an approval is a statement by a named person")
    return name


def approve(prefix: str, reviewer: str, profile: Optional[str] = None, note: str = "") -> dict:
    """Record an approval for every asset whose id starts with `prefix`. Returns what happened to each."""
    reviewer = _reviewer(reviewer)
    if profile and profile not in fitmod.PROFILES:
        sys.exit(f"unknown body profile {profile!r}; choose from {', '.join(fitmod.PROFILES)}")
    ledger = load_ledger()
    manifests = load_manifests()
    index = pinning.png_index(ART)
    view = pinning.evaluate(ledger, all_entries(manifests), index)
    current = {(i["record"]["assetId"], i["record"].get("profile") or None)
               for i in view["records"] if i["state"] == pinning.CURRENT}
    today = datetime.date.today().isoformat()
    result = {"added": [], "replaced": [], "alreadyApproved": [], "refused": [], "notAdapted": []}
    for entry in _matching(prefix, manifests):
        asset = entry["id"]
        if profile and profile not in entry.get("adaptedProfiles", []):
            result["notAdapted"].append(asset)          # native there, or unsupported: nothing to approve
            continue
        if not pinning.automated_pass(entry):
            result["refused"].append(f"{asset}: automated checks did not pass (status {entry['verification']['status']})")
            continue
        missing = pinning.missing_resources(entry, index)
        if missing:
            result["refused"].append(f"{asset}: resource files not found: {', '.join(missing)}")
            continue
        if (asset, profile) in current:
            result["alreadyApproved"].append(asset)
            continue
        stale = [r for r in ledger["approvals"] if r.get("assetId") == asset and (r.get("profile") or None) == profile]
        ledger["approvals"] = [r for r in ledger["approvals"] if r not in stale]
        ledger["approvals"].append({"assetId": asset, "profile": profile, "reviewer": reviewer, "date": today,
                                    "note": note, "contentHash": pinning.content_hash(entry, index, profile)})
        result["replaced" if stale else "added"].append(asset)
    if result["added"] or result["replaced"]:
        save_ledger(ledger)
    return result


def revoke(prefix: str, reviewer: str, profile: Optional[str] = None, note: str = "") -> List[dict]:
    """Remove approvals for every asset whose id starts with `prefix` and keep a record that they were removed.
    Without `profile` the part-level approval and every fit approval of the asset go; with it, only that fit."""
    reviewer = _reviewer(reviewer)
    ledger = load_ledger()
    ids = {e["id"] for e in _matching(prefix, load_manifests())}
    today = datetime.date.today().isoformat()
    removed = [r for r in ledger["approvals"]
               if r.get("assetId") in ids and (profile is None or (r.get("profile") or None) == profile)]
    if removed:
        ledger["approvals"] = [r for r in ledger["approvals"] if r not in removed]
        ledger["revocations"] += [{"assetId": r.get("assetId"), "profile": r.get("profile") or None,
                                   "approvedBy": r.get("reviewer"), "approvedOn": r.get("date"),
                                   "contentHash": r.get("contentHash"), "revokedBy": reviewer, "revokedOn": today,
                                   "note": note} for r in removed]
        save_ledger(ledger)
    return removed


def status() -> dict:
    """Where review stands, from the ledger and the files as they are now (not from the manifests' stamps)."""
    ledger = load_ledger()
    manifests = load_manifests()
    view = view_of(ledger, manifests)
    races, gear = manifests[0][2], manifests[1][2]
    packs = {}
    for part in races["parts"]:
        pack = packs.setdefault(part["pack"], {"layers": 0, "approved": 0, "renderLayers": 0, "renderApproved": 0,
                                               "adaptedProfiles": None, "approvedProfiles": None})
        ok = pinning.stamp(part, view)["status"] == "verified"
        pack["layers"] += 1
        pack["approved"] += ok
        if part["kind"] != "face":          # the renderer's recipe leaves the face overlays out
            pack["renderLayers"] += 1
            pack["renderApproved"] += ok
            adapted = set(part.get("adaptedProfiles", []))
            fits = set(view["profiles"].get(part["id"], {})) if ok else set()
            pack["adaptedProfiles"] = adapted if pack["adaptedProfiles"] is None else pack["adaptedProfiles"] & adapted
            pack["approvedProfiles"] = fits if pack["approvedProfiles"] is None else pack["approvedProfiles"] & fits
    for pack in packs.values():
        pack["rendersModular"] = pack["renderLayers"] > 0 and pack["renderApproved"] == pack["renderLayers"]
        pack["adaptedProfiles"] = sorted(pack["adaptedProfiles"] or [])
        pack["approvedProfiles"] = sorted(pack["approvedProfiles"] or [])
    groups = {}
    for item in gear["items"]:
        group = groups.setdefault(item["group"], {"items": 0, "approved": 0})
        group["items"] += 1
        group["approved"] += pinning.stamp(item, view)["status"] == "verified"
    entries = all_entries(manifests)
    approved = sum(pinning.stamp(e, view)["status"] == "verified" for e in entries)
    return {"packs": packs, "gear": groups,
            "totals": {"assets": len(entries), "approved": approved, "candidate": len(entries) - approved,
                       "packs": len(packs), "packsRenderingModular": sum(p["rendersModular"] for p in packs.values()),
                       "records": len(ledger["approvals"]), "revocations": len(ledger["revocations"])},
            "stale": [f"{pinning.describe(i['record'])}: {i['reason']}" for i in view["stale"]],
            "unknown": [pinning.describe(i["record"]) for i in view["unknown"]]}


def print_status(s: dict) -> None:
    print(f"{'pack':<24}{'layers':>9}  {'renders':<9} fits approved / adapted")
    for name, p in s["packs"].items():
        fits = f"{', '.join(p['approvedProfiles']) or '-'} / {', '.join(p['adaptedProfiles']) or 'none'}"
        print(f"{name:<24}{p['approved']:>4}/{p['layers']:<4}  {'modular' if p['rendersModular'] else 'legacy':<9} {fits}")
    print()
    print("gear (a QA record: gear approval does not change rendering)")
    for name, g in s["gear"].items():
        print(f"  {name:<12}{g['approved']:>3}/{g['items']}")
    t = s["totals"]
    print()
    print(f"{t['approved']} of {t['assets']} assets approved; {t['packsRenderingModular']} of {t['packs']} packs render "
          f"through the modular path; {t['records']} ledger records, {t['revocations']} revocations.")
    for line in s["stale"]:
        print("STALE:", line)
    for line in s["unknown"]:
        print("UNKNOWN ASSET:", line)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("approve", "revoke"):
        a = sub.add_parser(name)
        a.add_argument("prefix")
        a.add_argument("--reviewer", required=True)
        a.add_argument("--profile")
        a.add_argument("--note", default="")
    sub.add_parser("apply")
    st = sub.add_parser("status")
    st.add_argument("--json", action="store_true")
    args = ap.parse_args()
    if args.cmd == "status":
        s = status()
        print(json.dumps(s, indent=1, sort_keys=True)) if args.json else print_status(s)
        return
    if args.cmd == "approve":
        r = approve(args.prefix, args.reviewer, args.profile, args.note)
        print(f"approvals added: {len(r['added'])}, replaced (were stale): {len(r['replaced'])}, "
              f"already approved: {len(r['alreadyApproved'])}")
        if r["notAdapted"]:
            print(f"skipped {len(r['notAdapted'])} that do not adapt to {args.profile} (native there, or unsupported)")
        for line in r["refused"]:
            print("REFUSED:", line)
    elif args.cmd == "revoke":
        removed = revoke(args.prefix, args.reviewer, args.profile, args.note)
        print(f"approvals revoked: {len(removed)}")
        for rec in removed:
            print("  " + pinning.describe(rec))
    counts = apply()
    stale = counts.pop("stale")
    print(counts)
    for line in stale:
        print("STALE:", line)


if __name__ == "__main__":
    main()
