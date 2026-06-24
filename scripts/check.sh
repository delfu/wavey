#!/usr/bin/env bash
# Local pre-commit check: engine tests + app build, in one command.
# Run this before committing. It stands in for CI until GitHub Actions is
# set up (deferred — see Linear DEL-180); a future workflow can just call it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Engine tests (swift test)"
swift test --package-path Engine

echo "==> Generate Xcode project (xcodegen)"
xcodegen generate

echo "==> Build app (xcodebuild)"
xcodebuild -project Wavey.xcodeproj -scheme Wavey \
  -destination 'generic/platform=iOS Simulator' \
  -quiet build

echo "==> OK — engine green, app builds"
