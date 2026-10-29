#!/bin/bash
# Install Hedge into Applications.
# curl -fsSL https://raw.githubusercontent.com/qasim0786/hedge/main/install.sh | bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Hedge installs on a Mac."
  exit 1
fi

major="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$major" -lt 14 ]]; then
  echo "Hedge needs macOS 14 or later. This Mac is on $(sw_vers -productVersion)."
  exit 1
fi

REPO="qasim0786/hedge"
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/Hedge.dmg"
WORK="$(mktemp -d)"
MOUNT="$(mktemp -d)"
cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "$WORK"
  rmdir "$MOUNT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Downloading Hedge…"
if ! curl -fL --retry 3 --progress-bar -o "$WORK/Hedge.dmg" "$RELEASE_URL"; then
  echo "The Hedge disk image is not on GitHub releases yet."
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Install Xcode, then run this again, or download Hedge.dmg from https://github.com/${REPO}/releases"
    exit 1
  fi
  echo "Building from source. This takes a few minutes."
  git clone --depth 1 "https://github.com/${REPO}.git" "$WORK/src"
  bash "$WORK/src/scripts/make-dmg.sh" "$WORK/Hedge.dmg"
fi

echo "Installing…"
hdiutil attach "$WORK/Hedge.dmg" -nobrowse -mountpoint "$MOUNT" >/dev/null
if [[ ! -d "$MOUNT/Hedge.app" ]]; then
  echo "The disk image does not contain Hedge.app."
  exit 1
fi

if [[ -w /Applications ]]; then
  DEST="/Applications"
else
  DEST="${HOME}/Applications"
  mkdir -p "$DEST"
fi

rm -rf "${DEST}/Hedge.app"
ditto "$MOUNT/Hedge.app" "${DEST}/Hedge.app"
xattr -dr com.apple.quarantine "${DEST}/Hedge.app" 2>/dev/null || true

echo "Hedge is in ${DEST}."
echo "The first time macOS may say the developer cannot be verified. Right-click Hedge, choose Open, then Open again."
open "${DEST}/Hedge.app"
