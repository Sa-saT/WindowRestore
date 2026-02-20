# Window Restore — 仕様書

> 統合元: `REQUIREMENTS.md`（要件定義）+ `docs/SWIFT_ONLY_SPEC.md`（Swift単独仕様）  
> 最終更新: 2026-02-20（Xcode プロジェクト移行に伴い統合・改訂）

---

## 1. 基本情報

| 項目 | 内容 |
|------|------|
| アプリ名 | Window Restore |
| 目的 | macOS 上のウィンドウ配置（位置・サイズ・所属ディスプレイ）を記録・復元する |
| 対象 OS | macOS 13 (Ventura) 以降 |
| 実装言語 | Swift（純 Swift 実装） |
| フレームワーク | AppKit / CoreGraphics / Accessibility API / UserNotifications |
| ビルドシステム | **Xcode**（`.xcodeproj`） |
| UI 形態 | メニューバー常駐（`LSUIElement = true`、Dock 非表示） |
| 必要権限 | アクセシビリティ（他アプリのウィンドウ操作） |

> **Xcode 移行による変更点**
>
> | 変更前 | 変更後 |
> |--------|--------|
> | ~~Rust + Swift + FFI（cbindgen）~~ | Swift 単独 |
> | ~~Swift Package Manager（`Package.swift`）~~ | Xcode プロジェクト（`WindowRestore.xcodeproj`） |
> | ~~`scripts/make_app.sh` で手動 .app 生成~~ | Xcode が .app バンドルを自動生成 |
> | ~~`sips` + `iconutil` で手動 icns 変換~~ | Asset Catalog（`Assets.xcassets`） |
> | ~~対象 OS: macOS 15~~ | macOS 13+（Xcode Deployment Target に準拠） |

---

## 2. 機能要件

| 機能 | 説明 |
|------|------|
| ウィンドウ状態の保存 | 表示中ウィンドウの「アプリ名」「バンドル ID」「タイトル」「位置・サイズ」「所属ディスプレイ UUID」「Space ラベル」を取得し JSON で保存 |
| ウィンドウ状態の復元 | 保存 JSON を読み込み、Accessibility API（`AXUIElement`）で各ウィンドウを記録位置・サイズに移動 |
| マルチ Space 保存 | 複数の Space を順に切り替えながらラベル付きで一括保存 |
| インタラクティブ復元 | ラベル付きレイアウトを Space ごとに順次復元（ユーザーが切替を確認） |
| メニューバー UI | 常駐アイコン + ドロップダウンメニュー（保存・復元・レイアウト一覧・設定・終了） |
| レイアウト管理 | 名前付きレイアウトの作成・一覧表示・選択・削除・切り替え |
| 設定管理 | 自動復元、ディスプレイ変化検知等のオプションを `config.json` に保存 |
| 通知表示 | 操作結果（保存完了/復元完了/エラー）を macOS ネイティブ通知で表示 |
| 権限管理 | 起動時にアクセシビリティ許可をチェック。未許可時はユーザーに通知 |
| セカンダリディスプレイ対応 | 複数ディスプレイにステータスアイコンを表示 |

---

## 3. データモデル

### 3.1 WindowInfo

```swift
struct WindowInfo: Codable {
    let ownerName: String
    let bundleIdentifier: String?
    let windowName: String?
    let bounds: CGRect
    let displayUUID: String?
    let spaceNumber: Int?
    let layoutLabel: String?
}
```

### 3.2 レイアウト JSON フォーマット

保存先: `<base>/layouts/<name>.json`

```json
[
  {
    "ownerName": "Visual Studio Code",
    "bundleIdentifier": "com.microsoft.VSCode",
    "windowName": "project",
    "bounds": [[0, 0], [1600, 1200]],
    "displayUUID": "37D8832A-...",
    "spaceNumber": 1,
    "layoutLabel": "Space1"
  }
]
```

### 3.3 設定ファイルフォーマット

保存先: `<base>/config.json`

```json
{
  "auto_restore": false,
  "display_change_detection": true,
  "exclude_apps": ["com.apple.finder"],
  "restore_delay_ms": 1000,
  "max_retry_attempts": 3
}
```

---

## 4. ファイルパス

保存先の解決順序:

1. 環境変数 `WINDOW_RESTORE_DATA_DIR`
2. `~/Library/Application Support/window_restore/`
3. フォールバック: カレントディレクトリ `./target/window_restore/`

| 用途 | パス |
|------|------|
| レイアウト | `<base>/layouts/<name>.json` |
| 設定 | `<base>/config.json` |

---

## 5. アーキテクチャ

### 5.1 プロジェクト構造

```
window_restore/
├── WindowRestore.xcodeproj/      # Xcode プロジェクト
├── WindowRestore/                # アプリソース
│   ├── main.swift                # エントリポイント
│   ├── AppDelegate.swift         # ライフサイクル管理・メニューバー設定
│   ├── WindowManager.swift       # ウィンドウ取得/保存/復元（コアロジック）
│   ├── MenuController.swift      # メニュー UI
│   ├── PermissionManager.swift   # アクセシビリティ権限管理
│   ├── SettingsWindow.swift      # 設定画面
│   ├── LayoutSelector.swift      # レイアウト選択/削除 UI
│   ├── FileHelper.swift          # ファイル I/O ヘルパー
│   ├── LayoutAPI.swift            # レイアウト操作 API（内部は WindowManager を呼出）
│   ├── QuitWindow.swift          # 終了確認ウィンドウ
│   ├── SecondaryStatusIcons.swift # セカンダリディスプレイアイコン
│   ├── Info.plist
│   └── Assets.xcassets/
├── docs/
├── README.md
└── _archived_spm/                # 旧 SPM ファイル退避
```

> **Xcode 移行による変更点**
>
> | 変更前 | 変更後 |
> |--------|--------|
> | ~~`mac-app/Package.swift` + `mac-app/Sources/`~~ | `WindowRestore.xcodeproj` + `WindowRestore/` |
> | ~~`mac-app/Sources/Resources/` (SPM リソース)~~ | `WindowRestore/Assets.xcassets/` |
> | ~~`scripts/make_app.sh`（手動ビルド）~~ | Xcode の Build (Cmd+B) |
> | ~~`dist/`（手動出力先）~~ | Xcode DerivedData |

### 5.2 コンポーネント役割

| コンポーネント | 役割 |
|---|---|
| `WindowManager` | `CGWindowListCopyWindowInfo` でウィンドウ列挙、`AXUIElement` で復元、JSON I/O |
| `MenuController` | メニューバーのドロップダウンメニュー構築・操作ハンドリング |
| `PermissionManager` | `AXIsProcessTrusted()` による権限チェック・監視 |
| `FileHelper` | ディレクトリ解決・作成、JSON 読み書き、一覧・削除 |
| `LayoutAPI` | レイアウト操作のファサード。内部で `WindowManager` を呼び出す |
| `AppDelegate` | アプリライフサイクル管理、各コンポーネントの初期化・接続 |
| `SettingsWindow` | 設定 UI の表示・変更 |
| `LayoutSelector` | レイアウト一覧・選択・削除のダイアログ UI |
| `SecondaryStatusIcons` | マルチディスプレイ時のステータスアイコン表示 |

---

## 6. ウィンドウ取得の仕様

### 6.1 取得方法

`CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`

### 6.2 取得項目

| 項目 | ソース |
|------|--------|
| `ownerName` | `kCGWindowOwnerName` |
| `bundleIdentifier` | PID → `NSRunningApplication` → `bundleIdentifier` |
| `windowName` | `kCGWindowName` |
| `bounds` | `kCGWindowBounds` |
| `displayUUID` | `NSScreenNumber` → `CGDisplayCreateUUIDFromDisplayID` |
| `spaceNumber` | 任意項目 |

### 6.3 除外条件

- `kCGWindowLayer != 0`
- `ownerName` が Dock / Window Server / NotificationCenter / Control Center / Spotlight 等
- 幅または高さが 100px 未満

---

## 7. ウィンドウ復元の仕様

1. `AXIsProcessTrusted()` で権限確認（false なら中断・通知）
2. 保存 JSON を読み込み
3. 対象アプリの PID を `NSRunningApplication` で特定
4. `AXUIElementCreateApplication(pid)` → `kAXWindowsAttribute` でウィンドウ取得
5. `kAXPositionAttribute` / `kAXSizeAttribute` を `AXValueCreate` で設定
6. ウィンドウ未取得・アプリ未起動はスキップして続行

---

## 8. エラーハンドリング

- 権限なし: ユーザー通知 + システム設定への誘導
- ファイル I/O エラー: ログ出力 + 通知
- JSON パースエラー: ログ出力 + 通知
- ウィンドウ未取得 / アプリ未起動: スキップして続行

---

## 9. 非機能要件

| 項目 | 基準 |
|------|------|
| 起動時間 | 3 秒以内 |
| メモリ使用量 | 50MB 以下 |
| 復元時間 | 10 秒以内（100 ウィンドウ以下） |
| 対応アーキテクチャ | Intel / Apple Silicon |
| ディスプレイ | 複数ディスプレイ対応 |
| ネットワーク | オフライン動作（外部通信不要） |

---

## 10. 制約事項

- メニューバー常駐のみ（メインウィンドウなし）
- macOS 専用
- アクセシビリティ権限必須
- サンドボックス無効（Accessibility API の制約）

---

## 11. 配布

- **配布形式**: DMG（ディスクイメージ）
- **配布チャネル**: GitHub Releases
- **自動化**: GitHub Actions でタグ push → ビルド → DMG 作成 → Releases アップロード
- **詳細手順**: [`docs/RELEASE.md`](RELEASE.md) を参照

---

## 12. 将来拡張予定

- クラウド同期機能
- ウィンドウ配置の自動学習
- プラグインシステム

---

## 付録: Xcode 移行で廃止された旧仕様

以下は Rust + FFI 時代および SPM 時代の仕様で、現在は使用されていません。

<details>
<summary>旧 Rust FFI インターフェース（廃止）</summary>

```rust
// ffi.rs — Swift から C 互換 API で呼び出していた
#[no_mangle] pub extern "C" fn save_current_layout(name: *const c_char) -> i32;
#[no_mangle] pub extern "C" fn restore_layout(name: *const c_char) -> i32;
#[no_mangle] pub extern "C" fn get_layout_list() -> *mut c_char;
#[no_mangle] pub extern "C" fn delete_layout(name: *const c_char) -> i32;
#[no_mangle] pub extern "C" fn check_permissions() -> i32;
#[no_mangle] pub extern "C" fn get_last_error_message() -> *mut c_char;
```

→ 現在は `LayoutAPI.swift` が同等のメソッドを持つファサードとして機能し、内部で `WindowManager` を直接呼び出しています。

</details>

<details>
<summary>旧 Rust エラー型（廃止）</summary>

```rust
#[derive(Debug, thiserror::Error)]
pub enum WindowRestoreError {
    PermissionDenied(String),
    AppNotFound(String),
    WindowNotFound(String),
    DisplayNotFound(String),
    FileIOError(#[from] std::io::Error),
    JsonError(#[from] serde_json::Error),
}
```

→ Swift 側で `do/catch` + ログ出力 + 通知に置き換え済み。

</details>

<details>
<summary>旧ビルド手順（Rust + SPM、廃止）</summary>

```bash
# Rust ライブラリビルド
cargo build --release --target aarch64-apple-darwin

# C ヘッダー生成
cbindgen --config cbindgen.toml --crate window_restore --output mac-app/Bridging/window_restore.h

# SPM ビルド
cd mac-app && swift build -c release

# .app バンドル手動生成
bash scripts/make_app.sh
```

→ Xcode で Cmd+B（Build）するだけで .app が生成されます。

</details>

<details>
<summary>旧 WindowLevel enum（Rust、廃止）</summary>

```rust
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum WindowLevel { Normal = 0, Floating = 3, Modal = 8, Dock = 20 }
```

→ Swift 実装では `kCGWindowLayer == 0` のフィルタで代替。

</details>
