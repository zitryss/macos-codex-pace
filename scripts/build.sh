#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project CodexPace.xcodeproj -scheme CodexPace -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build
printf '\nBuilt app: %s/build/Build/Products/Debug/Codex Pace.app\n' "$PWD"
