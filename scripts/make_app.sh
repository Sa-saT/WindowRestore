#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="WindowRestore"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ICON_SRC="$ROOT_DIR/mac-app/Sources/Resources/window_dog_icon.png"

echo "[1/3] Building SwiftPM (release)"
pushd "$ROOT_DIR/mac-app" >/dev/null
swift build -c release
popd >/dev/null

echo "[2/3] Creating .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/mac-app/.build/release/mac-app" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat >"$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>WindowRestore</string>
  <key>CFBundleDisplayName</key>
  <string>WindowRestore</string>
  <key>CFBundleIdentifier</key>
  <string>local.window-restore</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>WindowRestore</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "[3/3] Generating app icon (.icns)"

# 固定パス: mac-app/Sources/Resources/window_dog_icon.png から .icns を生成
if [[ -f "$ICON_SRC" ]]; then
  ICONSET_DIR="$APP_DIR/Contents/Resources/AppIcon.iconset"
  ICNS_PATH="$APP_DIR/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET_DIR" "$ICNS_PATH"
  mkdir -p "$ICONSET_DIR"
  # 必須サイズを生成
  sips -z 16 16  "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32  "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32  "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64  "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  # 1024x1024 は @2x 相当
  sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
  # 中間生成物を削除（.iconset は不要）
  rm -rf "$ICONSET_DIR"
else
  echo "[warn] mac-app/Sources/Resources/window_dog_icon.png が見つかりませんでした。アプリアイコンは未設定です" >&2
fi

echo "[3/3] Done: $APP_DIR"
open "$ROOT_DIR/dist"

