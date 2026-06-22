#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PadSidecar"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/icon.iconset"
INFO_TEMPLATE="$ROOT_DIR/Resources/Info.plist"
PLISTBUDDY="/usr/libexec/PlistBuddy"

VERSION="${VERSION:-$("$PLISTBUDDY" -c 'Print :CFBundleShortVersionString' "$INFO_TEMPLATE")}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"

mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

xcrun clang \
  -fobjc-arc \
  -framework Foundation \
  "$ROOT_DIR/SidecarBridge.m" \
  -o "$RESOURCES_DIR/SidecarBridge"
chmod +x "$RESOURCES_DIR/SidecarBridge"

xcrun iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

cp "$INFO_TEMPLATE" "$CONTENTS_DIR/Info.plist"
"$PLISTBUDDY" -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
"$PLISTBUDDY" -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"

xcrun swiftc \
  -O \
  -module-name "$APP_NAME" \
  -framework Cocoa \
  -framework SwiftUI \
  -framework IOKit \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

codesign --force --deep --sign - "$APP_DIR"

echo "Built app bundle: $APP_DIR"
