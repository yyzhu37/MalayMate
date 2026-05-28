#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_DIR="$ROOT/build/MalayMate.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

swift build -c release
RELEASE_DIR="$(swift build -c release --show-bin-path)"
RESOURCE_BUNDLE="$RELEASE_DIR/MalayMate_MalayMateCore.bundle"

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  RESOURCE_BUNDLE="$(find "$ROOT/.build" -path "*/release/MalayMate_MalayMateCore.bundle" -type d | sort | tail -n 1)"
fi

if [[ -z "${RESOURCE_BUNDLE:-}" || ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing MalayMateCore resource bundle" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$RELEASE_DIR/MalayMate" "$MACOS_DIR/MalayMate"
cp "$ROOT/packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/MalayMate_MalayMateCore.bundle"
chmod +x "$MACOS_DIR/MalayMate"

test -f "$RESOURCES_DIR/MalayMate_MalayMateCore.bundle/starter_deck.json"
test -f "$RESOURCES_DIR/MalayMate_MalayMateCore.bundle/open_frequency_starter_deck.json"

if command -v codesign >/dev/null 2>&1; then
  xattr -cr "$APP_DIR"
  codesign --force --deep --sign - "$APP_DIR"
  find "$APP_DIR" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
fi

echo "$APP_DIR"
