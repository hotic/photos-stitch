#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="拼成长图.app"
EXECUTABLE_NAME="PhotosStitch"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
INSTALL_APP="$INSTALL_DIR/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

mkdir -p "$BUILD_DIR"
PACKAGE_ROOT="$(mktemp -d "$BUILD_DIR/package.XXXXXX")"
APP_DIR="$PACKAGE_ROOT/$APP_NAME"
ICONSET_DIR="$PACKAGE_ROOT/AppIcon.iconset"
ICON_FILE="$PACKAGE_ROOT/AppIcon.icns"

cleanup() {
  if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -u "$APP_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$PACKAGE_ROOT"
}

trap cleanup EXIT

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift "$ROOT_DIR/scripts/generate_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

swiftc \
  -O \
  -parse-as-library \
  -framework AppKit \
  -framework Photos \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"

for lproj in "$ROOT_DIR"/Resources/*.lproj; do
  cp -R "$lproj" "$APP_DIR/Contents/Resources/"
done

codesign --force --deep --sign - "$APP_DIR" >/dev/null

mkdir -p "$INSTALL_DIR"
rsync -a --delete "$APP_DIR/" "$INSTALL_APP/"
codesign --force --deep --sign - "$INSTALL_APP" >/dev/null

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$INSTALL_APP" >/dev/null 2>&1 || true
fi

echo "Installed to: $INSTALL_APP"
