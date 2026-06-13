# CLAUDE.md — Window Restore プロジェクト コンテキスト

## プロジェクト概要

macOS メニューバー常駐アプリ（純 Swift / Xcode プロジェクト）
- ウィンドウの位置・サイズ・ディスプレイを JSON に保存・復元する
- macOS 13+ / Intel & Apple Silicon 対応
- サンドボックス無効（Accessibility API 使用のため）
- `LSUIElement=true` → Dock 非表示・メニューバー専用

## ビルド

```bash
xcodebuild -scheme WindowRestore -configuration Debug build
```

Xcode 以外でのビルドは非サポート。Swift Package Manager 不可。

## ファイル構成

```
WindowRestore/
├── WindowManager.swift      # ★ コアロジック（保存/復元/ウィンドウ列挙）
├── AppDelegate.swift        # ★ 各コンポーネントの初期化・メニュー操作ハンドリング
├── LayoutAPI.swift          # WindowManager へのファサード（エラー型変換）
├── FileHelper.swift         # JSON I/O・ディレクトリ解決
├── MenuController.swift     # メニューバー UI
├── PermissionManager.swift  # アクセシビリティ権限監視
├── LayoutSelector.swift     # レイアウト選択・削除ダイアログ
├── SettingsWindow.swift     # 設定 UI（UserDefaults）
└── QuitWindow.swift         # 終了確認ウィンドウ
```

呼び出し階層:
```
AppDelegate → LayoutAPI → WindowManager → FileHelper
```

## データ保存先

```
~/Library/Application Support/window_restore/layouts/<name>.json
```

環境変数 `WINDOW_RESTORE_DATA_DIR` で上書き可能。

## 設定（UserDefaults）

設定画面（`SettingsWindow`）に出るのは次の2項目のみ。どちらも `UserDefaults` 標準ドメインに保存し、`WindowManager` が実処理に反映する。

| キー | 反映先 | 既定値 |
|------|--------|--------|
| `restoreDelay` | `restoreWindows` の各ウィンドウ適用間隔（200〜5000ms にクランプ） | 200 |
| `excludedApps` | `fetchVisibleAppWindows` の保存対象フィルタ（所有者名で除外） | なし |

> 自動復元・ディスプレイ変化検知は「最小・ローカル完結」のコンセプトに照らして削除済み（2026-06-13）。復活させない。

## WindowInfo 構造体

```swift
struct WindowInfo: Codable {
    let ownerName: String
    let bundleIdentifier: String?  // アプリの永続識別子（PIDの代替）
    let windowName: String?
    let bounds: CGRect
    let displayUUID: String?
    let layoutLabel: String?
    // spaceNumber は削除済み（Phase 6.1 / 2026-03-17）— 常に nil で無価値
}
```

## Save フロー

1. `AppDelegate.saveCurrentLayout(name:)`
2. 既存ファイルがあれば上書き確認 → `deleteLayout` で削除
3. `saveWindowsAppend(name:label:)` で Space ラベル付き保存（Space1, Space2, ...）
4. 「次の Space を保存しますか？」→ Yes なら Space 切替を促してループ

- `fetchVisibleAppWindows()` は **全物理ディスプレイのウィンドウを 1 回のスナップショットで取得**（ディスプレイごとの処理不要）
- 単一 Space でも `saveWindowsAppend` を使用（保存フローは 1 パターンのみ）

## Restore フロー

1. `AppDelegate.restoreLayout(name:)` → `LayoutAPI.restoreLayout(name:)` → `WindowManager.restoreWindows(name:)`
2. `deduplicateForRestore` で重複エントリを除去（接続中ディスプレイのエントリを優先）
3. 各エントリを `restoreSingleWindow` で処理（200ms インターバル）

**AX API は Space を横断する**ため、Space 切替なしで全 Space のウィンドウに適用できる。
インタラクティブ復元は不要と判断し削除済み（2026-03-17）。

## ウィンドウマッチングロジック（restoreSingleWindow）

1. `bundleIdentifier` でアプリを特定（未起動なら `NSWorkspace.openApplication(at:configuration:)` で起動・最大 10 秒待機）
2. `kAXWindowsAttribute` で全ウィンドウ取得（全 Space 分）
3. `bestMatchWindow` でウィンドウを選択:
   - タイトル一致が 1 件 → そのまま採用
   - タイトル一致が複数 → 保存座標に最も近いウィンドウ（`closestWindow`）
   - タイトル不一致 → 全候補から保存座標に最も近いウィンドウ
   - `restoreWindows` が割り当て済みウィンドウを `assigned` で追跡し、候補から除外（同一アプリ複数ウィンドウの二重割り当て防止／Phase 7・2026-06-12）

## 画面外配置防止（clampWindowToScreen）

復元時に必ず適用:
1. `displayUUID` が一致するスクリーンを探す → 一致すればそのスクリーンに収める
2. 一致なし かつ 画面外 → 最近傍スクリーンに収める
3. 完全に画面内 → そのまま（スクリーンをまたぐ場合は UUID 一致優先）

座標系: NSScreen は Cocoa 座標（y 上向き）、CGWindow は y 下向き。変換: `CGWindow.y = mainH - nsFrame.maxY`

## 重複エントリ除去（deduplicateForRestore）

キー: `bundleId + windowName + displayUUID`
- 第 1 パス: 接続中ディスプレイのエントリを優先採用
- 第 2 パス: 残りのエントリを追加
- 異なるディスプレイの同名ウィンドウはそれぞれ独立して復元

## メニューバーアイコン

`NSImage(named: "MenuBarIcon")` で `Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.png` を読み込む。
- `isTemplate = true` → ダーク/ライトモードで自動反転（白黒 PNG 推奨）
- 読み込み失敗時は `createDogMenuBarIcon()` でテキストベースのフォールバック

アイコン変更時は `MenuBarIcon.imageset/` 内の PNG を差し替えるだけでよい。

## テスト

`test.command` をダブルクリック → Terminal で全テストを実行。
- プロジェクト構造・ソース整合性・ビルド・JSON/FileHelper・Dedup・画面外クランプ・ウィンドウマッチングの 8 セクション

## 重要な制約

- **アクセシビリティ権限必須**: `AXIsProcessTrusted()` → .app バンドルに紐づく（バイナリ直起動は不可）
- **サンドボックス無効**: Entitlements で明示的に無効化済み
- **プライベート API 禁止**: `CGSGetWindowWorkspace` など CGSPrivate 系は使用しない
- **Space 自動検出不可**: macOS 公開 API で信頼できる Space ID は取得できない

## コーディング規約

- `WindowManager` はロジックのみ（UI を持たない）
- UI ダイアログ（NSAlert）は `AppDelegate` に集約
- エラーは `throw` で伝播、ユーザー通知は `AppDelegate` の `showErrorNotification`
- `usleep` による待機は許容（UI フリーズはユーザー判断で許容）
- プライベート API・非公開フレームワーク使用禁止

## やってはいけないこと

- `async/await` 化（UI フリーズ許容のため不要・ユーザー判断）
- `kCGWindowWorkspace` の使用（Restore に活かす公開 API がなく無価値）
- `CGSGetWindowWorkspace` などプライベート API（安定性リスク）
- Space 自動切替（公開 API なし）
- インタラクティブ復元の再実装（一括復元と等価・削除済み）
- `spaceNumber` フィールドの復活（常に nil・削除済み）
- ログイン時自動復元 / ディスプレイ変化検知の実装（スコープ外・削除済み）
- クラウド同期・配置の自動学習・プラグイン機構（最小・ローカル完結を維持）

## Phase 6 完了済みタスク（2026-03-17）

| タスク | 内容 |
|--------|------|
| 6.1 | `WindowInfo.spaceNumber` 削除（4 箇所） |
| 6.2 | `bestMatchWindow` / `closestWindow` でウィンドウ選択精度向上 |
| 6.3 | `deduplicateForRestore` で重複エントリ除去 |
| 追加 | `clampWindowToScreen` で画面外配置防止 |
| 追加 | 保存・復元フローを 1 パターンに統合（インタラクティブ復元廃止） |

## Phase 7 完了済みタスク（2026-06-12）

| タスク | 内容 |
|--------|------|
| 7.1 | `restoreWindows` で割り当て済みウィンドウを追跡し、同一アプリ複数ウィンドウの二重割り当てを防止 |
| 7.2 | `closestWindow` の AXValue 強制キャストを型ID検証付きに変更（クラッシュ耐性向上） |

詳細は `docs/TASK_SCHEDULE.md` を参照。
