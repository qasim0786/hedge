#!/bin/bash
# Build a Release Hedge.app and pack a drag-to-Applications disk image.
# Usage: scripts/make-dmg.sh [path/to/Hedge.dmg]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-"$ROOT/dist/Hedge.dmg"}"
DERIVED="$ROOT/build/Release"

echo "Building Hedge…"
xcodebuild \
  -project "$ROOT/Hedge.xcodeproj" \
  -scheme Hedge \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  build

APP="$DERIVED/Build/Products/Release/Hedge.app"
if [[ ! -d "$APP" ]]; then
  echo "Build finished without Hedge.app."
  exit 1
fi

STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

ditto "$APP" "$STAGE/Hedge.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
hdiutil create \
  -volname "Hedge" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$OUT"

echo "Wrote $OUT"
