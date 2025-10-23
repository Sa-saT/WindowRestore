#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Window Restore"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

echo "[1/5] Building Rust (release)"
cargo build --release -q

echo "[2/5] Building SwiftPM (release)"
pushd "$ROOT_DIR/mac-app" >/dev/null
swift build -c release
popd >/dev/null

echo "[3/5] Creating .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Frameworks" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/mac-app/.build/release/mac-app" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/target/release/libwindow_restore.dylib" "$APP_DIR/Contents/Frameworks/"

cat >"$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Window Restore</string>
  <key>CFBundleDisplayName</key>
  <string>Window Restore</string>
  <key>CFBundleIdentifier</key>
  <string>local.window-restore</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>Window Restore</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "[4/5] Fixing rpath"
install_name_tool -id "@rpath/libwindow_restore.dylib" "$APP_DIR/Contents/Frameworks/libwindow_restore.dylib"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "[5/5] Done: $APP_DIR"
open "$ROOT_DIR/dist"

