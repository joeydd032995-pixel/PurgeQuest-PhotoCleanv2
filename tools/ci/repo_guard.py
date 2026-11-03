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
  8. Widget palette: the home-screen widgets' colors match the app's Classic palette, stay readable
     on the widget backgrounds, and the widget views use no fixed colors.
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

# 8. widget palette
# The widget target is self-contained, so its colors are a copy of the app's Classic palette. Keep the
# copy honest: same values, readable on the widget backgrounds, and (below) no fixed colors in the views.
WIDGET_DIR = IOS / "PurgeQuestWidget"
WIDGET_TOKENS = (
    "canvasTop", "surface", "hairline", "textPrimary", "textSecondary",
    "amber", "sapphire", "crimson", "emerald",
)
WIDGET_FLOORS = {  # (Light, Dark) minimum contrast, as in ThemePaletteTests
    "textPrimary": (7, 7), "textSecondary": (4.5, 4.5),
    "amber": (4.5, 3), "sapphire": (4.5, 3), "crimson": (4.5, 3), "emerald": (4.5, 3),
}
APP_PAIR = (
    r"ThemePair\(light:\s*0x([0-9A-Fa-f]{6}),\s*dark:\s*ThemeRGB\("
    r"(?:hex:\s*0x([0-9A-Fa-f]{6})|red:\s*([0-9.]+),\s*green:\s*([0-9.]+),\s*blue:\s*([0-9.]+))\)\)"
)


def eight_bit(value):
    return int(float(value) * 255 + 0.5)


def app_pair(light, dark_hex, red, green, blue):
    dark = int(dark_hex, 16) if dark_hex else (eight_bit(red) << 16) | (eight_bit(green) << 8) | eight_bit(blue)
    return int(light, 16), dark


def luminance(rgb):
    def channel(value):
        value /= 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return 0.2126 * channel((rgb >> 16) & 255) + 0.7152 * channel((rgb >> 8) & 255) + 0.0722 * channel(rgb & 255)


def contrast_ratio(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


theme_src = (IOS / "PurgeQuest/Models/ThemePalette.swift").read_text()
classic_src = theme_src.split("static let classic = ThemeNeutrals(", 1)[1].split("static let verdigris", 1)[0]
app_tokens = {m.group(1): app_pair(*m.groups()[1:]) for m in re.finditer(r"(\w+):\s*" + APP_PAIR, classic_src)}
for m in re.finditer(r"static let (\w+)\s*=\s*" + APP_PAIR, theme_src):
    app_tokens.setdefault(m.group(1), app_pair(*m.groups()[1:]))

palette_file = WIDGET_DIR / "WidgetPalette.swift"
if not palette_file.exists():
    failures.append("widget palette: ios/PurgeQuestWidget/WidgetPalette.swift is missing")
    widget_tokens = {}
else:
    widget_tokens = {
        m.group(1): (int(m.group(2), 16), int(m.group(3), 16))
        for m in re.finditer(
            r"static let (\w+)\s*=\s*WidgetPair\(light:\s*0x([0-9A-Fa-f]{6}),\s*dark:\s*0x([0-9A-Fa-f]{6})\)",
            strip_comments(palette_file.read_text()),
        )
    }
    for token in WIDGET_TOKENS:
        if token not in widget_tokens:
            failures.append(f"widget palette: WidgetPalette.{token} is missing")
        elif token not in app_tokens:
            failures.append(f"widget palette: no Classic '{token}' in ThemePalette.swift to compare with (parser out of date?)")
        elif widget_tokens[token] != app_tokens[token]:
            failures.append(
                "widget palette: %s is light %06X / dark %06X but the app's Classic palette has light %06X / dark %06X"
                % (token, *widget_tokens[token], *app_tokens[token])
            )
    for token in sorted(set(widget_tokens) - set(WIDGET_TOKENS)):
        failures.append(f"widget palette: WidgetPalette.{token} is not in WIDGET_TOKENS, so nothing guards it")
    for token, floors in WIDGET_FLOORS.items():
        for index, appearance in enumerate(("Light", "Dark")):
            for background in ("canvasTop", "surface"):
                if token in widget_tokens and background in widget_tokens:
                    got = contrast_ratio(widget_tokens[token][index], widget_tokens[background][index])
                    if got < floors[index]:
                        failures.append(
                            f"widget palette: {token} on {background} in {appearance} is {got:.2f}:1, below {floors[index]}:1"
                        )

widget_views = strip_comments((WIDGET_DIR / "PurgeQuestWidget.swift").read_text())
for pattern, what in (  # the .black font weight is fine; only black colors are banned
    (r"\bColor\(red:", "a raw Color(red:) literal"),
    (r"\.white\b", ".white"),
    (r"\bColor\.black\b|(?:foregroundStyle|fill|stroke|tint|background)\(\s*\.black\b", "a black color"),
):
    if re.search(pattern, widget_views):
        failures.append(f"widget palette: PurgeQuestWidget.swift uses {what}; use the Color.widget* tokens")

if failures:
    print("repo_guard FAILED:")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print(f"repo_guard ok ({len(used)} seasonal IDs, {len(catalog_ids)} catalog items, {len(family_cases)} family icons, {len(widget_tokens)} widget tokens)")
