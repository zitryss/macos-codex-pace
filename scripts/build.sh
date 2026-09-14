#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project CodexPace.xcodeproj -scheme CodexPace -configuration Release -derivedDataPath .build/xcode CODE_SIGN_IDENTITY=- REGISTER_APP=NO build
printf '\nBuilt app: %s/.build/xcode/Build/Products/Release/Codex Pace.app\n' "$PWD"
