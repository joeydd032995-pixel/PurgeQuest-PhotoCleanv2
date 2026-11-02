#!/usr/bin/env python3
"""Static guards for PurgeQuest's non-negotiable contracts. Runs anywhere (no Xcode needed).

  python3 -I tools/ci/repo_guard.py

Checks:
  1. Fully offline: no networking APIs in the app, widget, or test sources.
  2. No third-party dependencies: the Xcode project has no Swift package references.
  3. Recoverable deletion only: PHAssetChangeRequest.deleteAssets is called from PhotoLibraryService alone.
  4. Seasonal exclusiveCosmeticIDs all exist in the seeded cosmetic catalog.
  5. Every swift_harness source/test file named in run.sh exists.
  6. Appearance contract: nothing pins the app to Light or Dark (the user's setting decides).
  7. Design assets the code relies on exist: the emblem and one icon per Bestiary family.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "ios"
failures = []


def swift_files(*dirs):
    for d in dirs:
        yield from (IOS / d).rglob("*.swift")


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//.*", "", text)


# 1. offline
NETWORK = re.compile(
    r"\b(URLSession|URLRequest|NWConnection|NWPathMonitor|CFNetwork|WKWebView|SFSafariViewController|"
    r"Network\.framework|MultipeerConnectivity)\b|^\s*import\s+(Network|WebKit|SafariServices|MultipeerConnectivity)\b",
    re.M,
)
for f in swift_files("PurgeQuest", "PurgeQuestWidget"):
    for m in NETWORK.finditer(strip_comments(f.read_text())):
        failures.append(f"offline contract: {f.relative_to(ROOT)} uses network API '{m.group(0).strip()}'")

# 2. no packages
pbx = (IOS / "PurgeQuest.xcodeproj/project.pbxproj").read_text()
if re.search(r"XCRemoteSwiftPackageReference|XCLocalSwiftPackageReference|XCSwiftPackageProductDependency", pbx):
    failures.append("dependency contract: project.pbxproj references a Swift package")
for name in ("Package.resolved", "Podfile", "Cartfile"):
    if any(IOS.rglob(name)):
        failures.append(f"dependency contract: found {name}")

# 3. recoverable deletion
allowed = "ios/PurgeQuest/Services/PhotoLibraryService.swift"
for f in swift_files("PurgeQuest", "PurgeQuestWidget"):
    rel = str(f.relative_to(ROOT))
    code = strip_comments(f.read_text())
    if "PHAssetChangeRequest.deleteAssets" in code and rel != allowed:
        failures.append(f"deletion contract: {rel} deletes assets outside PhotoLibraryService")
    if re.search(r"FileManager[^\n]*removeItem[^\n]*(asset|photo|PHAsset)", code, re.I):
        failures.append(f"deletion contract: {rel} removes photo files directly")
if "PHAssetChangeRequest.deleteAssets" not in (ROOT / allowed).read_text():
    failures.append("deletion contract: PhotoLibraryService no longer uses PHAssetChangeRequest.deleteAssets")

# 4. seasonal cosmetic IDs
seasonal = (IOS / "PurgeQuest/Services/SeasonalEventService.swift").read_text()
catalog = (IOS / "PurgeQuest/Services/GameDataService.swift").read_text()
catalog_ids = set(re.findall(r'CosmeticItem\(\s*id:\s*"([^"]+)"', catalog))
used = set()
for block in re.findall(r"exclusiveCosmeticIDs:\s*\[([^\]]*)\]", seasonal):
    used |= set(re.findall(r'"([^"]+)"', block))
if not used:
    failures.append("seasonal check: found no exclusiveCosmeticIDs (parser out of date?)")
for cid in sorted(used - catalog_ids):
    failures.append(f"seasonal check: exclusive cosmetic '{cid}' is not in the seeded catalog")

# 5. harness files exist
run_sh = (ROOT / "tools/swift_harness/run.sh").read_text()
for m in re.finditer(r"for f in ([^;]+); do", run_sh):
    for n in m.group(1).split():
        if not (IOS / "PurgeQuest" / f"{n}.swift").exists():
            failures.append(f"harness: run.sh lists missing source {n}.swift")
for m in re.finditer(r"for t in ([^;]+); do", run_sh):
    for n in m.group(1).split():
        if not (IOS / "PurgeQuestTests" / f"{n}.swift").exists():
            failures.append(f"harness: run.sh lists missing test {n}.swift")

# 6. no pinned appearance
for f in swift_files("PurgeQuest"):
    if re.search(r"preferredColorScheme\(\s*\.(dark|light)\s*\)", strip_comments(f.read_text())):
        failures.append(f"appearance contract: {f.relative_to(ROOT)} pins the color scheme; use AppearanceMode")
if re.search(r"INFOPLIST_KEY_UIUserInterfaceStyle\s*=\s*(Dark|Light)", pbx):
    failures.append("appearance contract: project.pbxproj pins UIUserInterfaceStyle")

# 7. design assets exist
catalog_dir = IOS / "PurgeQuest/Assets.xcassets"
family_src = (IOS / "PurgeQuest/Models/MonsterFamily.swift").read_text()
family_cases = re.findall(r"^\s*case (\w+)\s*$", family_src.split("var displayName")[0], re.M)
if len(family_cases) != 6:
    failures.append(f"design assets: expected 6 MonsterFamily cases, parsed {len(family_cases)}")
for case in family_cases:
    folder = catalog_dir / f"Family-{case}.imageset"
    if not (folder / "Contents.json").exists() or not list(folder.glob("*.svg")):
        failures.append(f"design assets: missing icon imageset Family-{case}")
emblem = catalog_dir / "PurgeQuestEmblem.imageset"
if not (emblem / "Contents.json").exists() or len(list(emblem.glob("*.png"))) < 1:
    failures.append("design assets: missing PurgeQuestEmblem imageset")

if failures:
    print("repo_guard FAILED:")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print(f"repo_guard ok ({len(used)} seasonal IDs, {len(catalog_ids)} catalog items, {len(family_cases)} family icons)")
