#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="WindowNest"
APP_SOURCE="${1:-/Applications/$APP_NAME.app}"
DIST_DIR="$ROOT_DIR/dist"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_SOURCE/Contents/Info.plist")"
SAFE_VERSION="${APP_VERSION//[^0-9A-Za-z._-]/-}"
ZIP_PATH="$DIST_DIR/$APP_NAME-$SAFE_VERSION-macOS.zip"
TEMP_DIR="$ROOT_DIR/.zip-work"
STAGE_DIR="$TEMP_DIR/stage"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "App not found: $APP_SOURCE" >&2
  exit 1
fi

rm -rf "$TEMP_DIR"
mkdir -p "$DIST_DIR" "$STAGE_DIR"
rm -f "$DIST_DIR/$APP_NAME-macOS.zip" "$DIST_DIR"/"$APP_NAME"-*-macOS.zip(N)

cp -R "$APP_SOURCE" "$STAGE_DIR/$APP_NAME.app"

(
  cd "$STAGE_DIR"
  /usr/bin/zip -qry "$ZIP_PATH" "$APP_NAME.app"
)

rm -rf "$TEMP_DIR"

echo "Zip archive: $ZIP_PATH"
