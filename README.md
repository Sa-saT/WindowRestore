# Window Restore

macOS向けウィンドウ位置・サイズ・ディスプレイ復元アプリケーション

## 概要

Window Restoreは、macOS上でユーザーのウィンドウ配置（位置・サイズ・所属ディスプレイ）を記録・復元し、必要に応じて該当アプリを起動してレイアウトを再現するアプリケーションです。

## 特徴

- 🪟 **ウィンドウ状態の保存・復元**: 現在開いているウィンドウの位置・サイズ・ディスプレイ情報を記録
- 📱 **メニューバー常駐**: メニューバーに常駐し、簡単な操作でレイアウトを管理
- 🎯 **複数レイアウト対応**: 名前付きレイアウトを複数保存・切り替え可能
- ⚙️ **柔軟な設定**: 自動復元・ディスプレイ変化検知などの設定オプション
- 🔐 **セキュア**: アクセシビリティ権限を適切に管理

## 技術仕様

- **対象OS**: macOS 15 (Sequoia) 以降
- **開発言語**: Rust (ロジック) + Swift (UI)
- **フレームワーク**: AppKit
- **ビルドシステム**: Cargo + Xcode

## ステータス

本プロジェクトは現在「開発中」です（個人用途）。配布・署名やインストーラー提供は現時点で行いません。

Rustロジックは安定運用を目指して実装・テスト中、Swift側はメニューバーUI/FFI連携を中心に動作検証中です。

## インストール

1. リリースページから最新版をダウンロード
2. `.app`ファイルを`/Applications/`にコピー
3. アプリケーションを起動
4. アクセシビリティ権限を許可

## 使用方法

1. メニューバーのWindow Restoreアイコンをクリック
2. 「現在のレイアウトを保存」でレイアウトを保存
3. 「レイアウトを復元」で保存されたレイアウトを復元
4. 「レイアウト一覧」で保存されたレイアウトを管理

## 開発

### 必要な環境（開発・動作確認）

- Rust 1.70+
- Xcode Command Line Tools（Xcode本体は不要。配布やコード署名を行う場合はXcode推奨）
- macOS 15+

### ビルド手順（開発）

```bash
# Rustライブラリのビルド
cargo build --release --target aarch64-apple-darwin

# Cヘッダーの生成
cbindgen --config cbindgen.toml --crate window_restore --output mac-app/Bridging/window_restore.h

# SwiftPMでのビルド（CLT環境）
cd mac-app
swift build -c release
```

### テスト

```bash
# 単体テスト
WINDOW_RESTORE_DATA_DIR=$(pwd)/target/window_restore cargo test

# 統合テスト（純粋I/O）
WINDOW_RESTORE_DATA_DIR=$(pwd)/target/it_window_restore cargo test --test integration_tests
```

### .app の作成と起動（ログイン項目に追加したい場合）

```bash
# .appバンドルを作成（dist/Window Restore.app）
bash scripts/make_app.sh

# 起動
open "dist/Window Restore.app"
```

- 初回起動で通知許可のダイアログが表示されます。許可してください。
- アクセシビリティ権限が必要な場合、システム設定の案内に従って有効化してください。
- ログイン項目への追加: システム設定 → 一般 → ログイン項目 → 「+」で `dist/Window Restore.app` を追加

## ライセンス

MIT License

## コンタクト / サポートポリシー

本プロジェクトは現時点で公開Issue/PRの受け入れを前提としていません。改善提案や不具合の共有が必要な場合は、リリースノートやドキュメントを参照のうえ、適宜バージョン更新をお待ちください。

運用・サポートに関する個別対応は行っていません。
