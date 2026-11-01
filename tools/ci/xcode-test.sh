#!/usr/bin/env bash
# Run the same checks CI runs, on a Mac with Xcode. Usage: tools/ci/xcode-test.sh [--ui]
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/../.."
python3 -I tools/ci/repo_guard.py
udid="$(xcrun simctl list -j devices available | jq -r '[.devices | to_entries[] | select(.key | test("iOS-(1[89]|[2-9][0-9])-")) | .value[] | select(.name | startswith("iPhone")) | .udid][0] // empty')"
[[ -n "$udid" ]] || { echo "No iOS 18+ iPhone simulator available" >&2; exit 1; }
run() { xcodebuild -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug \
  -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO "$@"; }
run -only-testing:PurgeQuestTests test
[[ "${1:-}" == "--ui" ]] && run -only-testing:PurgeQuestUITests/ForgeUITests test
echo "all checks passed"
