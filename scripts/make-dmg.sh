#!/usr/bin/env bash
# Packages dist/Sticky Note.app into dist/StickyNote-<version>.dmg with an
# Applications shortcut so the app can be installed by drag and drop.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Sticky Note"
VERSION="$(tr -d '[:space:]' < VERSION)"
DIST="dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/StickyNote-$VERSION.dmg"
STAGE="$DIST/dmg-root"

[ -d "$APP" ] || { echo "Build the app first: scripts/build.sh"; exit 1; }

echo "==> Staging DMG contents"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov "$DMG"
rm -rf "$STAGE"

ls -lh "$DMG"
echo "==> Done: $DMG"
