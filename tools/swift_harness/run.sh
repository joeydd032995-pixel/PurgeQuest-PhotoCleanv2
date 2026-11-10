#!/usr/bin/env bash
# Compile and test the pure-Foundation Swift sources on a Linux toolchain (no Xcode needed).
#   SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh [extra swift test args]
# Covers the model, fitting and recolor logic, the duplicate engine, the thumbnail rules, the monster
# classifier with the content that names monsters, and room targeting, each with its test suite (the
# two lists below are the exact set). UIKit/SwiftUI/SwiftData code (SpriteEngine, Forge views,
# PhotoLibraryService) is compiled and tested only by Xcode / CI (.github/workflows/ios.yml).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${HARNESS_DIR:-$(mktemp -d)}"
SWIFT="${SWIFT_BIN:-swift}"
APP="$REPO/ios/PurgeQuest"
TESTS="$REPO/ios/PurgeQuestTests"
mkdir -p "$WORK/Sources/PurgeQuest" "$WORK/Tests/PurgeQuestTests"
cd "$WORK"
for f in Models/ModularCharacterFoundation Models/ModularAssetCatalog Models/HeldGearFit Models/RecolorMath Models/ForgeDraft Models/HeroAppearance Models/LookRecolor Models/ThemePalette Models/AppearanceMode Models/ColorTheme Models/MediaItem Models/MonsterClassification Models/GameContent Services/DuplicateDetection Services/ThumbnailAnalysis Services/BoundedConcurrency Services/RoomTargeting Services/MonsterClassifier Services/MonsterType+Counting Services/CaptureSignals Services/VideoFrameSignals Services/VisionTextSignals; do
  ln -sf "$APP/$f.swift" "Sources/PurgeQuest/$(basename "$f").swift"
done
# These import SwiftUI only for a Color (an accent, a frame tint); compile them against Foundation + the stub Color.
for s in Models/HeroRace Models/MonsterType Models/MonsterFamily Models/MonsterRarity; do
  sed 's/^import SwiftUI$/import Foundation/' "$APP/$s.swift" > "Sources/PurgeQuest/$(basename "$s").swift"
done
cp "$HERE/Stubs.swift" Sources/PurgeQuest/Stubs.swift
for t in ModularCharacterFoundationTests ModularGearTests ModularManifestFileTests LookRecolorTests ThemePaletteTests DuplicateEngineTests ThumbnailAnalysisTests BoundedConcurrencyTests RoomTargetingTests ClassifierRulesTests ClusterReasonTests ContentReachabilityTests CaptureSignalTests ClassifierPrecedenceTests GameContentTests; do ln -sf "$TESTS/$t.swift" "Tests/PurgeQuestTests/$t.swift"; done
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
