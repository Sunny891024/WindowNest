#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="WindowNest"
APP_SOURCE="${1:-/Applications/$APP_NAME.app}"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$ROOT_DIR/.dmg-work"
STAGE_DIR="$WORK_DIR/stage"
BACKGROUND_DIR="$STAGE_DIR/.background"
BACKGROUND_PATH="$BACKGROUND_DIR/background.png"
RW_DMG="$WORK_DIR/$APP_NAME-installer-temp.dmg"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_SOURCE/Contents/Info.plist")"
SAFE_VERSION="${APP_VERSION//[^0-9A-Za-z._-]/-}"
FINAL_DMG="$DIST_DIR/$APP_NAME-$SAFE_VERSION-Installer.dmg"
VOLUME_NAME="$APP_NAME Installer"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "App not found: $APP_SOURCE" >&2
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$BACKGROUND_DIR" "$DIST_DIR"

env CLANG_MODULE_CACHE_PATH=/tmp/windownest-clang-cache swift "$ROOT_DIR/scripts/generate_dmg_background.swift" "$BACKGROUND_PATH"

cp -R "$APP_SOURCE" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
chflags hidden "$BACKGROUND_DIR"

rm -f "$RW_DMG" "$DIST_DIR/$APP_NAME-Installer.dmg" "$DIST_DIR"/"$APP_NAME"-*-Installer.dmg(N)

hdiutil create \
  -srcfolder "$STAGE_DIR" \
  -volname "$VOLUME_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  "$RW_DMG"

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(echo "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"
MOUNT_POINT="/Volumes/$VOLUME_NAME"

if [[ -z "$DEVICE" ]]; then
  echo "Failed to mount DMG" >&2
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {140, 140, 860, 600}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 16
        set background picture of opts to file ".background:background.png"
        set position of item "$APP_NAME.app" to {180, 220}
        set position of item "Applications" to {540, 220}
        update without registering applications
        delay 1
        close
        open
        delay 1
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE"

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
rm -f "$RW_DMG"

echo "DMG created: $FINAL_DMG"
