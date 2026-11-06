#!/usr/bin/env bash
# Release build of Harf, ad-hoc signed and zipped to dist/Harf.zip.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

rm -rf build/Release-derived dist
mkdir -p dist

xcodebuild \
  -scheme Harf \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/Release-derived \
  CODE_SIGN_IDENTITY=- \
  build

APP="build/Release-derived/Build/Products/Release/Harf.app"
codesign --force --deep -s - "$APP"
ditto -c -k --keepParent "$APP" dist/Harf.zip
echo "Built dist/Harf.zip"
