#!/usr/bin/env bash
# Builds StickyNote as a universal (Apple Silicon + Intel) binary and wraps it
# into dist/Sticky Note.app. Run on macOS with Xcode command line tools.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Sticky Note"
EXEC_NAME="StickyNote"
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
DIST="dist"
APP="$DIST/$APP_NAME.app"
ARCHS=(--arch arm64 --arch x86_64)

echo "==> Building $EXEC_NAME $VERSION ($BUILD_NUMBER)"
if ! swift build -c release "${ARCHS[@]}" --product "$EXEC_NAME"; then
  echo "==> Universal build failed, falling back to the host architecture"
  ARCHS=()
  swift build -c release --product "$EXEC_NAME"
fi
# ${ARCHS[@]+...} keeps bash 3.2 (macOS default) happy when the array is empty.
BIN_DIR="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --product "$EXEC_NAME" --show-bin-path)"
BIN="$BIN_DIR/$EXEC_NAME"
[ -x "$BIN" ] || { echo "Binary not found at $BIN"; exit 1; }

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXEC_NAME"
chmod +x "$APP/Contents/MacOS/$EXEC_NAME"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD_NUMBER/g" packaging/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Creating app icon"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
SRC_ICON="packaging/icon-1024.png"
for size in 16 32 128 256 512; do
  double=$((size * 2))
  sips -z "$size" "$size" "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$double" "$double" "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=2 "$APP"
lipo -info "$APP/Contents/MacOS/$EXEC_NAME" || true

echo "==> Done: $APP"
