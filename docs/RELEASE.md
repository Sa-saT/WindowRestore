# Window Restore — DMG 配布・リリース手順

> 最終更新: 2026-02-20

---

## 概要

GitHub Releases で DMG（ディスクイメージ）を配布する。  
ユーザーは README の **Download** ボタンから DMG をダウンロードし、`.app` を `/Applications/` にドラッグ&ドロップするだけでインストールが完了する。

---

## 1. リリースフロー全体像

```
タグ push (v1.0.0)
  → GitHub Actions 起動
    → Xcode ビルド (.app)
    → コード署名（オプション）
    → DMG 作成
    → GitHub Releases にアップロード
  → README の Download リンクが自動で最新版を指す
```

---

## 2. DMG 作成手順（ローカル）

### 2.1 Xcode でリリースビルド

```bash
xcodebuild -project WindowRestore.xcodeproj \
  -scheme WindowRestore \
  -configuration Release \
  -derivedDataPath ./build \
  clean build
```

ビルド済み `.app` の場所:

```
./build/Build/Products/Release/WindowRestore.app
```

### 2.2 DMG 作成

```bash
# 一時ディレクトリに .app と /Applications エイリアスを配置
DMG_DIR=$(mktemp -d)
cp -R ./build/Build/Products/Release/WindowRestore.app "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# DMG 生成
hdiutil create -volname "WindowRestore" \
  -srcfolder "$DMG_DIR" \
  -ov -format UDZO \
  WindowRestore.dmg

rm -rf "$DMG_DIR"
```

生成物: `WindowRestore.dmg`

ユーザー体験: DMG を開くと `WindowRestore.app` と `Applications` フォルダが並び、ドラッグ&ドロップでインストールできる。

### 2.3 動作確認

```bash
open WindowRestore.dmg
```

---

## 3. GitHub Actions による自動化

`.github/workflows/release.yml` を作成する。

```yaml
name: Release DMG

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Build
        run: |
          xcodebuild -project WindowRestore.xcodeproj \
            -scheme WindowRestore \
            -configuration Release \
            -derivedDataPath ./build \
            clean build

      - name: Create DMG
        run: |
          DMG_DIR=$(mktemp -d)
          cp -R ./build/Build/Products/Release/WindowRestore.app "$DMG_DIR/"
          ln -s /Applications "$DMG_DIR/Applications"
          hdiutil create -volname "WindowRestore" \
            -srcfolder "$DMG_DIR" \
            -ov -format UDZO \
            WindowRestore.dmg
          rm -rf "$DMG_DIR"

      - name: Upload to GitHub Releases
        uses: softprops/action-gh-release@v2
        with:
          files: WindowRestore.dmg
```

### 使い方

```bash
git tag v1.0.0
git push origin v1.0.0
```

タグを push するだけで、GitHub Actions がビルド → DMG 作成 → Releases へのアップロードを自動実行する。

---

## 4. README のダウンロードリンク

```markdown
[**Download (DMG)**](https://github.com/<user>/WindowRestore/releases/latest/download/WindowRestore.dmg)
```

`/releases/latest/download/` は常に最新リリースのアセットを指すため、タグを更新するだけでリンクが自動的に最新版になる。

---

## 5. コード署名（オプション）

配布時にコード署名を行うと、macOS の Gatekeeper 警告を回避できる。

### 5.1 ローカル署名

```bash
codesign --force --deep --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
  ./build/Build/Products/Release/WindowRestore.app
```

### 5.2 公証（Notarization）

```bash
# zip 化して Apple に提出
ditto -c -k --keepParent WindowRestore.app WindowRestore.zip

xcrun notarytool submit WindowRestore.zip \
  --apple-id "<APPLE_ID>" \
  --team-id "<TEAM_ID>" \
  --password "<APP_SPECIFIC_PASSWORD>" \
  --wait

# Staple（公証チケットを .app に埋め込み）
xcrun stapler staple WindowRestore.app
```

### 5.3 署名なしの場合

未署名の .app は初回起動時に Gatekeeper でブロックされる。ユーザーに以下を案内する:

1. Finder で `WindowRestore.app` を右クリック →「開く」
2. または: システム設定 > プライバシーとセキュリティ >「このまま開く」

---

## 6. バージョニング規則

| タグ | 用途 |
|------|------|
| `v1.0.0` | 正式リリース |
| `v1.1.0-beta.1` | ベータ版（GitHub Releases で Pre-release にマーク） |

Xcode プロジェクトの `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` もタグに合わせて更新する。

---

## 7. チェックリスト（リリース前）

- [ ] `MARKETING_VERSION` を更新（Info.plist / Xcode Build Settings）
- [ ] `CURRENT_PROJECT_VERSION` をインクリメント
- [ ] ローカルで Release ビルドが通ることを確認
- [ ] DMG を手動作成し、インストール → 起動 → 基本操作を動作確認
- [ ] `git tag vX.Y.Z && git push origin vX.Y.Z`
- [ ] GitHub Releases ページでアセットとリリースノートを確認
