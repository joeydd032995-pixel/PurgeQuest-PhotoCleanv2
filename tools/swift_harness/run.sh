#!/usr/bin/env bash
# Compile and test the pure-Foundation Swift sources on a Linux toolchain (no Xcode needed).
#   SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh [extra swift test args]
# Covers: ModularCharacterFoundation, ModularAssetCatalog, HeldGearFit, RecolorMath, ForgeDraft,
# HeroAppearance, ThemePalette, AppearanceMode + their test suites. UIKit/SwiftUI/SwiftData code (SpriteEngine, Forge views) is
# compiled and tested only by Xcode / CI (.github/workflows/ios.yml).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${HARNESS_DIR:-$(mktemp -d)}"
SWIFT="${SWIFT_BIN:-swift}"
APP="$REPO/ios/PurgeQuest"
TESTS="$REPO/ios/PurgeQuestTests"
mkdir -p "$WORK/Sources/PurgeQuest" "$WORK/Tests/PurgeQuestTests"
cd "$WORK"
for f in Models/ModularCharacterFoundation Models/ModularAssetCatalog Models/HeldGearFit Models/RecolorMath Models/ForgeDraft Models/HeroAppearance Models/ThemePalette Models/AppearanceMode; do
  ln -sf "$APP/$f.swift" "Sources/PurgeQuest/$(basename "$f").swift"
done
# HeroRace.swift imports SwiftUI for `accent`; compile it against Foundation + the stub Color.
sed 's/^import SwiftUI$/import Foundation/' "$APP/Models/HeroRace.swift" > Sources/PurgeQuest/HeroRace.swift
cp "$HERE/Stubs.swift" Sources/PurgeQuest/Stubs.swift
for t in ModularCharacterFoundationTests ModularGearTests ModularManifestFileTests ThemePaletteTests; do ln -sf "$TESTS/$t.swift" "Tests/PurgeQuestTests/$t.swift"; done
cat > Package.swift <<'PKG'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PQHarness",
    products: [.library(name: "PurgeQuest", targets: ["PurgeQuest"])],
    targets: [
        .target(name: "PurgeQuest", path: "Sources/PurgeQuest", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "PurgeQuestTests", dependencies: ["PurgeQuest"], path: "Tests/PurgeQuestTests", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
PKG
export PQ_REPO_ROOT="$REPO"
echo "harness: $WORK"
"$SWIFT" test "$@"
