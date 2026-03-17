# CLAUDE.md — Window Restore プロジェクト コンテキスト

## プロジェクト概要

macOS メニューバー常駐アプリ（純 Swift / Xcode プロジェクト）
- ウィンドウの位置・サイズ・ディスプレイをJSONに保存・復元する
- macOS 13+ / Intel & Apple Silicon 対応
- サンドボックス無効（Accessibility API 使用のため）
- `LSUIElement=true` → Dock非表示・メニューバー専用

## ビルド

```bash
xcodebuild -scheme WindowRestore -configuration Debug build
```

Xcode 以外でのビルドは非サポート。Swift Package Manager 不可。

## 重要な制約

- **アクセシビリティ権限必須**: `AXIsProcessTrusted()` → .app バンドルに紐づく
- **サンドボックス無効**: Entitlements で明示的に無効化済み
- **プライベートAPI禁止**: `CGSGetWindowWorkspace` など CGSPrivate 系は使用しない
- **Space自動検出不可**: macOS 公開APIで信頼できる Space ID は取得できない

## アーキテクチャ

```
AppDelegate.swift       ← 各コンポーネントの初期化・メニュー操作ハンドリング
  ↓ 呼び出し
LayoutAPI.swift         ← WindowManager へのファサード（エラー型変換）
  ↓ 呼び出し
WindowManager.swift     ← コアロジック（保存・復元・ウィンドウ列挙）
  ↓ 使用
FileHelper.swift        ← JSON I/O・ディレクトリ解決
```

サポートコンポーネント:
- `MenuController.swift` — メニューバー UI
- `PermissionManager.swift` — アクセシビリティ権限監視
- `LayoutSelector.swift` — レイアウト選択ダイアログ
- `SettingsWindow.swift` — 設定 UI（UserDefaults）

## データ保存先

```
~/Library/Application Support/window_restore/layouts/<name>.json
```

環境変数 `WINDOW_RESTORE_DATA_DIR` で上書き可能。

## Save フロー

1. `saveCurrentLayout(name:)` — AppDelegate
2. 既存ファイルがあれば上書き確認 → `deleteLayout` で削除
3. `saveWindowsAppend(name:label:)` — Space ラベル付きで保存
4. 「他のSpaceもありますか？」と確認 → ユーザーがSpace切替 → ループ

`fetchVisibleAppWindows()` は **全物理ディスプレイのウィンドウを1回のスナップショットで取得**する（ディスプレイごとの処理不要）。

## Restore フロー

1. `restoreLayout(name:)` — AppDelegate
2. `LayoutAPI.restoreLayout(name:)` → `restoreWindows(name:)`
3. JSON の全エントリを `restoreSingleWindow` で処理（ラベル有無問わず一括）

**AX API は Space を横断する**ため、ユーザーが Space を切り替えなくても全 Space のウィンドウに適用できる。インタラクティブ復元は不要と判断し削除済み（2026-03-17）。

## ウィンドウマッチングロジック（restoreSingleWindow）

1. `bundleIdentifier` でアプリを特定（未起動なら起動して最大10秒待機）
2. `kAXWindowsAttribute` で全ウィンドウ取得（全Space分）
3. `windowName` でタイトル一致を優先、なければ `axWindows.first!`（先頭）

### 既知の問題点（Phase 6 対応予定）

| 問題 | 優先度 | 場所 |
|---|---|---|
| `spaceNumber` が常に nil → フィールド削除 | 高 | `WindowInfo` 構造体 |
| 同一タイトル複数ウィンドウ時に `first!` で誤マッチ | 高 | `restoreSingleWindow` |
| 複数Space保存で同アプリが重複登録・上書き | 中 | `saveWindowsAppend` / Restore |

詳細は `docs/TASK_SCHEDULE.md` Phase 6 を参照。

## コーディング規約

- `WindowManager` はロジックのみ（UI を持たない）
- UI ダイアログ（NSAlert）は `AppDelegate` に集約
- エラーは `throw` で伝播、ユーザー通知は `AppDelegate` の `showErrorNotification`
- `usleep` による待機は許容（UIフリーズはユーザー判断で許容）
- プライベートAPI・非公開フレームワーク使用禁止

## やってはいけないこと

- `async/await` 化（UIフリーズ許容のため不要・ユーザー判断）
- `kCGWindowWorkspace` の使用（Restore に活かす手段がなく無価値）
- `CGSGetWindowWorkspace` などプライベートAPI（安定性・審査リスク）
- Space 自動切替（公開API なし）
- インタラクティブ復元の再実装（一括復元と等価）
