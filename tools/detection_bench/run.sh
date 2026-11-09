#!/usr/bin/env bash
# Build and run the real-photo benchmark against the app's own pure Swift sources (Linux, no Xcode).
#   SWIFT_BIN=/path/to/swift tools/detection_bench/run.sh PREPARED_DIR [dedupe|quality|scaling]
# PREPARED_DIR comes from tools/detection_bench/prepare.py. See tools/detection_bench/README.md.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${BENCH_DIR:-$(mktemp -d)}"
SWIFT="${SWIFT_BIN:-swift}"
APP="$REPO/ios/PurgeQuest"
mkdir -p "$WORK/Sources/bench"
# Every pure-Foundation source the benchmark measures. Add new pure engine files here.
for f in Services/DuplicateDetection Services/ThumbnailAnalysis; do
  ln -sf "$APP/$f.swift" "$WORK/Sources/bench/$(basename "$f").swift"
done
cp "$HERE/bench.swift" "$WORK/Sources/bench/main.swift"
cat > "$WORK/Package.swift" <<'PKG'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PQBench",
    targets: [.executableTarget(name: "bench", path: "Sources/bench", swiftSettings: [.swiftLanguageMode(.v5), .unsafeFlags(["-Ounchecked"])])]
)
PKG
cd "$WORK"
"$SWIFT" build -c release --product bench 2>&1 | grep -E "error|warning: unre|Compiling|Build complete" | tail -5
./.build/release/bench "$@"
