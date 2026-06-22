#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PadSidecar"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
WORK_DIR="$BUILD_DIR/dmg-work"
STAGING_DIR="$WORK_DIR/$APP_NAME"
PLISTBUDDY="/usr/libexec/PlistBuddy"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  echo "Run scripts/build_app.sh first." >&2
  exit 1
fi

VERSION="${VERSION:-$("$PLISTBUDDY" -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")}"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

rm -rf "$WORK_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"

diskutil image create from \
  --format UDZO \
  "$STAGING_DIR" \
  "$DMG_PATH"

echo "Packaged DMG: $DMG_PATH"
