# Swift単独仕様（Window Restore）

本ドキュメントは、macOS用ウィンドウ配置の記録/復元アプリをSwift単独で実装するための仕様です。既存UI/UX（メニューバー常駐UI、設定ウィンドウ）はそのまま維持します。

## 目的
- ユーザーが任意のウィンドウ配置（位置・サイズ・ディスプレイ）を保存し、後から復元できるようにする。
- 記録対象はユーザー操作可能なアプリケーションウィンドウ。システムウィンドウは除外。
- 実装言語はSwiftのみ。データ永続化はJSON。

## データモデル
```swift
struct WindowInfo: Codable {
    let ownerName: String
    let pid: Int
    let windowName: String?
    let bounds: CGRect
    let displayUUID: String?
    let spaceNumber: Int?
}
```

## フェーズ
1) 取得（現在の配置）
- `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` を使用。
- 除外条件:
  - 所有アプリ名が `Dock`/`Window Server`/`NotificationCenter`/`Control Center`/`Spotlight` 等
  - `kCGWindowLayer != 0`
  - 幅・高さが100px未満
- 取得項目:
  - `ownerName`（kCGWindowOwnerName）
  - `pid`（kCGWindowOwnerPID）
  - `windowName`（kCGWindowName）
  - `bounds`（kCGWindowBounds）
  - `displayUUID`（`NSScreenNumber` → `CGDisplayCreateUUIDFromDisplayID` で解決。なければDisplayID文字列）
  - `spaceNumber`（任意・未実装）

2) JSON保存/読み込み
- `JSONEncoder`（`.prettyPrinted`/`.sortedKeys`）で保存、`JSONDecoder`で読み込み。
- 保存先（優先順）:
  1. 環境変数 `WINDOW_RESTORE_DATA_DIR`
  2. `~/Library/Application Support/window_restore`
  3. フォールバック: カレントディレクトリ `./target/window_restore`
- パス:
  - レイアウト: `<base>/layouts/<name>.json`
  - 設定: `<base>/config.json`

3) 復元
- `AXIsProcessTrusted()` によるアクセシビリティ許可が必須。
- `AXUIElementCreateApplication(pid)` → `kAXWindowsAttribute` からウィンドウ取得。
- `kAXPositionAttribute` と `kAXSizeAttribute` を `AXValueCreate` で設定し、保存時の `bounds.origin` と `bounds.size` を適用。
- ディスプレイ構成変化時の位置調整は今後拡張可能。

## 実装コンポーネント
- `WindowManager.swift`
  - `fetchVisibleAppWindows()` 現在のウィンドウ配列取得
  - `saveWindows(name:)` / `loadWindows(name:)` JSON I/O
  - `restoreWindows(name:)` 復元処理（AX API）
  - `listLayouts()` / `deleteLayout(name:)`
  - `hasAccessibilityPermission()` 権限確認
- `FileHelper.swift`
  - ディレクトリ解決/作成、JSON保存/読込、一覧/削除
- `RustAPI.swift`
  - 既存呼び出し互換のFacade。内部で `WindowManager` を呼び出すSwift実装に置換済み。
- 既存UI（`MenuController`/`LayoutSelector`/`SettingsWindow`/`AppDelegate`）
  - 変更最小化でSwift実装へ接続済み。

## エラーハンドリング
- 権限なし/ファイルI/O/JSONエラーはログ出力し、必要に応じ通知表示。
- ウィンドウ未取得・アプリ未起動等はスキップして続行。

## ビルド/実行
- SwiftPM:
  - `cd mac-app && swift build`
- 初回実行時:
  - システム設定 > プライバシーとセキュリティ > アクセシビリティ で当アプリを許可。

## 既知事項
- `NSUserNotification` は非推奨API（現状UI維持のため据え置き）。将来 `UserNotifications` での置換を推奨。
- Space番号は未実装（任意項目）。必要時に拡張。
