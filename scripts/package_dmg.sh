#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Snapper"
BUILD_SCRIPT="$ROOT_DIR/scripts/build_app.sh"
BUILD_APP="$ROOT_DIR/.build/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
VOLUME_NAME="$APP_NAME"

fail() {
  echo "Error: $1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Required macOS tool '$1' was not found."
}

echo "Preparing clean distribution output..."
rm -rf "$DIST_APP" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

require_tool ditto
require_tool hdiutil

echo "Building $APP_NAME.app with local ad-hoc signing..."
"$BUILD_SCRIPT"

[[ -d "$BUILD_APP" ]] || fail "App bundle was not produced at $BUILD_APP."
[[ -f "$BUILD_APP/Contents/Info.plist" ]] || fail "App bundle is missing Contents/Info.plist."
[[ -x "$BUILD_APP/Contents/MacOS/$APP_NAME" ]] || fail "App bundle is missing executable Contents/MacOS/$APP_NAME."

echo "Copying app bundle into dist..."
ditto "$BUILD_APP" "$DIST_APP"

# Future Developer ID signing/notarization can operate on $DIST_APP before staging.
echo "Staging DMG contents..."
ditto "$DIST_APP" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/Install Snapper.txt" <<'INSTRUCTIONS'
Install Snapper by dragging Snapper.app to the Applications shortcut.

This free build is ad-hoc signed and not Developer ID notarized. On first launch,
macOS may require right-clicking Snapper and choosing Open, or approving the app
from Privacy & Security settings. Snapper also requires Accessibility permission
to move and resize windows.
INSTRUCTIONS

echo "Creating compressed read-only DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created: $DMG_PATH"
