# Window Restore - 修正版要件定義仕様書

## 1. 基本情報

**アプリ名**: Window Restore  
**目的**: macOS上でユーザーのウィンドウ配置（位置・サイズ・所属ディスプレイ）を記録・復元し、必要に応じて該当アプリを起動してレイアウトを再現する  
**対象OS**: macOS 15 (Sequoia) 以降  
**構成言語/技術**:
- ロジック部: Rust
- UI（メニューバー常駐ステータスアイコン・メニュー）: Swift + AppKit
- FFIブリッジ: cbindgen + extern "C"
- ビルドシステム: Cargo + Xcode

**必要権限**: アクセシビリティ（他アプリのウィンドウ操作のため）

## 2. 機能要件

| 機能 | 説明 |
|------|------|
| ウィンドウ状態の保存 | 現在開いているアプリケーションウィンドウの「アプリ名」「バンドルID」「タイトル」「位置・サイズ（x, y, width, height）」「所属ディスプレイのUUID」「ウィンドウレベル」を取得し、JSON形式で保存 |
| ウィンドウ状態の復元 | 保存されたJSONを読み込み、該当アプリが未起動なら起動 → ウィンドウを記録された位置・サイズ・ディスプレイ上に移動・配置 |
| メニューバーUI | メニューバーに常駐アイコンを表示し、ドロップダウンメニューとして「保存」「復元」「レイアウト一覧」「設定」「終了」を提供 |
| レイアウト管理 | 名前付きレイアウトを複数保存可能。保存済みレイアウトの一覧表示・選択・削除・切り替えを可能にする |
| 設定管理 | 自動復元オプション・ディスプレイ変化検知オプション等を持つ設定を config.json に保存し、起動時/設定画面から変更可能とする |
| 通知表示 | 操作（保存完了/復元完了/エラー発生など）時に macOS のネイティブ通知を表示 |
| 権限管理 | 起動時にアクセシビリティ許可をチェック。許可がない場合、機能を制限しユーザーに案内表示 |
| 権限エラー時の自動対応 | PermissionDenied発生時に通知表示 + システム設定を自動で開く |

## 3. 技術仕様

### 3.1 JSONフォーマット

```json
{
  "layout_name": "Work Setup",
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z",
  "windows": [
    {
      "app_name": "Visual Studio Code",
      "bundle_id": "com.microsoft.VSCode",
      "title": "project",
      "frame": { "x": 0, "y": 0, "width": 1600, "height": 1200 },
      "display_uuid": "UUID-Display-00",
      "window_level": "Normal",
      "is_minimized": false,
      "is_hidden": false
    }
  ]
}
```

### 3.1.1 WindowLevel定義

```rust
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum WindowLevel {
    Normal = 0,
    Floating = 3,
    Modal = 8,
    Dock = 20,
}
```

### 3.2 設定ファイルフォーマット

```json
{
  "auto_restore": false,
  "display_change_detection": true,
  "exclude_apps": ["com.apple.finder"],
  "minimize_hidden_windows": true,
  "restore_delay_ms": 1000,
  "max_retry_attempts": 3,
  "scan_interval_ms": 5000,
  "max_memory_usage_mb": 50
}
```

### 3.3 ファイルパス

- **レイアウト保存先**: `~/Library/Application Support/window_restore/layouts/{name}.json`
- **設定ファイル**: `~/Library/Application Support/window_restore/config.json`
- **ログファイル**: `~/Library/Logs/window_restore/app.log`

### 3.4 エラーハンドリング

各コマンド（保存/復元等）は `Result<(), WindowRestoreError>` 型を返し、失敗時にはユーザー通知およびログ出力を行う。

```rust
#[derive(Debug, thiserror::Error)]
pub enum WindowRestoreError {
    #[error("Permission denied: {0}")]
    PermissionDenied(String),
    #[error("Application not found: {0}")]
    AppNotFound(String),
    #[error("Window not found: {0}")]
    WindowNotFound(String),
    #[error("Display not found: {0}")]
    DisplayNotFound(String),
    #[error("File I/O error: {0}")]
    FileIOError(#[from] std::io::Error),
    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),
}
```

### 3.4.1 PermissionDenied発生時の処理

```
PermissionDenied発生時の処理:
1. ユーザー通知: "アクセシビリティ権限が必要です"
2. システム設定を自動で開く: Privacy & Security > Accessibility
3. アプリは制限モードで動作継続（保存機能のみ無効化）
```

## 4. アーキテクチャ設計

### 4.1 プロジェクト構造

```
window_restore/
├── Cargo.toml
├── build.rs
├── cbindgen.toml
├── src/
│   ├── lib.rs
│   ├── window_scanner.rs
│   ├── window_restorer.rs
│   ├── layout_manager.rs
│   ├── config.rs
│   ├── app_launcher.rs
│   ├── display_manager.rs
│   ├── permission_checker.rs
│   ├── notification.rs
│   └── ffi.rs
├── mac-app/
│   ├── MacApp.xcodeproj
│   ├── Sources/
│   │   ├── AppDelegate.swift
│   │   ├── MenuController.swift
│   │   ├── PermissionManager.swift
│   │   ├── LayoutSelector.swift
│   │   └── NotificationManager.swift
│   └── Bridging/
│       ├── window_restore.h
│       └── module.modulemap
├── tests/
│   ├── integration_tests.rs
│   └── unit_tests.rs
└── README.md
```

### 4.2 モジュール構成

#### 4.2.1 コアモジュール

- **window_scanner**: ウィンドウ情報取得
- **window_restorer**: ウィンドウ配置復元
- **layout_manager**: レイアウト管理
- **config**: 設定管理
- **app_launcher**: アプリ起動支援
- **display_manager**: ディスプレイ管理
- **permission_checker**: 権限チェック
- **notification**: 通知管理

#### 4.2.2 Swift補助モジュール

- **PermissionManager.swift**: アクセシビリティ権限チェック、システム設定への誘導、権限状態の監視
- **LayoutSelector.swift**: レイアウト一覧表示UI、レイアウト選択・削除インターフェース

#### 4.2.3 FFIインターフェース

```rust
// ffi.rs
#[no_mangle]
pub extern "C" fn save_current_layout(name: *const c_char) -> i32;

#[no_mangle]
pub extern "C" fn restore_layout(name: *const c_char) -> i32;

#[no_mangle]
pub extern "C" fn get_layout_list() -> *mut c_char;

#[no_mangle]
pub extern "C" fn delete_layout(name: *const c_char) -> i32;

#[no_mangle]
pub extern "C" fn check_permissions() -> i32;

#[no_mangle]
pub extern "C" fn get_last_error_message() -> *mut c_char;
```

## 5. 非機能要件

### 5.1 パフォーマンス要件

- **起動時間**: 3秒以内
- **メモリ使用量**: 50MB以下
- **ウィンドウスキャン間隔**: 5秒間隔（設定可能）
- **復元時間**: 10秒以内（100ウィンドウ以下）

### 5.2 セキュリティ要件

- アクセシビリティ権限の適切な管理
- ファイルアクセスの最小権限原則
- ユーザーデータの暗号化（オプション）

### 5.3 互換性要件

- macOS 15 (Sequoia) 以降
- Intel/Apple Silicon 両対応
- 複数ディスプレイ環境対応

## 6. 開発・配布要件

### 6.1 ビルド手順

1. **Rustライブラリのビルド**
   ```bash
   cargo build --release --target aarch64-apple-darwin
   cargo build --release --target x86_64-apple-darwin
   ```

2. **Cヘッダーの生成**
   ```bash
   cbindgen --config cbindgen.toml --crate window_restore --output mac-app/Bridging/window_restore.h
   ```

3. **macOSアプリのビルド**
   ```bash
   xcodebuild -project mac-app/MacApp.xcodeproj -scheme MacApp -configuration Release
   ```

4. **Universal Binaryの作成（オプション）**
   ```bash
   # Intel + Apple Silicon統合バイナリの作成
   lipo -create \
     target/x86_64-apple-darwin/release/libwindow_restore.a \
     target/aarch64-apple-darwin/release/libwindow_restore.a \
     -output target/universal/libwindow_restore.a
   ```

### 6.2 配布要件

- **コード署名**: Apple Developer ID
- **プライバシー説明**: アクセシビリティ権限の説明
- **配布形式**: .app パッケージ
- **インストール先**: /Applications/

### 6.3 テスト要件

- **単体テスト**: 各モジュールのテスト
- **統合テスト**: FFIブリッジのテスト
- **UIテスト**: メニュー操作のテスト
- **パフォーマンステスト**: メモリ使用量・実行時間のテスト

## 7. 制約事項

- オフライン使用前提（外部サーバ通信不要）
- メインウィンドウを表示しない（メニューバー常駐のみ）
- macOS専用（Windows/Linux対応なし）
- アクセシビリティ権限必須

## 8. 将来拡張予定

- クラウド同期機能
- ウィンドウ配置の自動学習
- 複数ユーザー対応
- プラグインシステム

---

**作成日**: 2024年1月15日  
**バージョン**: 2.1  
**最終更新**: 2024年1月15日（改善案反映）
