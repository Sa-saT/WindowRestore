# Window Restore — 作業履歴（タスク管理）

> 最終更新: 2026-06-13（旧 Rust / FFI 工程を削除し純 Swift 化後の履歴に整理）

## プロジェクト概要

- **プロジェクト名**: Window Restore
- **実装**: Swift 単独（Xcode プロジェクト / AppKit・CoreGraphics・Accessibility API）
- **UI 形態**: メニューバー常駐（`LSUIElement = true`）

> 初期は別構成で試作したが、純 Swift 実装に作り直した（refactor: 6ca65c7）。
> 本書は純 Swift 化以降の改善作業（Phase 6〜）を記録する。

---

## Phase 6: コード品質・復元精度の改善（改善フェーズ）

> 純 Swift 化（refactor: 6ca65c7）以降に特定された問題への対処

### ✅ 6.1 データ構造の整理

- [x] `WindowInfo.spaceNumber: Int?` を削除
  - `WindowInfo` 構造体・`fetchVisibleAppWindows`・`saveWindowsAppend`・`replaceWindowsForLabel` 全4箇所から除去済み

### ✅ 6.2 ウィンドウマッチング精度の向上

- [x] `restoreSingleWindow` のウィンドウ選択を `bestMatchWindow` に刷新
  - タイトル一致1件 → そのまま採用
  - タイトル一致が複数 → 保存座標に最も近いウィンドウを選択（`closestWindow`）
  - タイトル不一致 → 全候補から保存座標に最も近いウィンドウを選択

### ✅ 6.3 Save時の重複エントリ対処

- [x] `deduplicateForRestore` を実装し `restoreWindows` に組み込み
  - 接続中ディスプレイのエントリを優先（第1パス）
  - `bundleId + windowName + displayUUID` が同一のエントリは先着1件のみ採用
  - 異なるディスプレイの同名ウィンドウはそれぞれ独立して復元

### ⬜ 6.4 対応不要と判断した項目

- [対応不要] 未起動アプリ起動中の UI フリーズ → ユーザー判断でそのまま許容
- [対応不要] 未起動アプリの `async/await` 化 → UIフリーズ許容のため不要
- [対応不要] 配置失敗時のユーザー通知 → 通知不要との判断
- [対応不要] `kCGWindowWorkspace` の使用 → Restore に活かす公開APIがなく無価値
- [対応不要] インタラクティブ復元 → 一括復元と等価と判明・削除済み

---

## Phase 7: 復元の正確性・クラッシュ耐性の改善（コードレビュー指摘対応）

> 2026-06-12 のコードレビューで特定された問題への対処

### ✅ 7.1 同一アプリ複数ウィンドウの取り違え防止（復元正確性）

- [x] `restoreWindows` で「割り当て済み AXUIElement」を追跡し、`bestMatchWindow` の候補から除外する
  - 現状: 各 `restoreSingleWindow` が独立に候補を選ぶため、タイトルが空/同一の同一アプリ複数ウィンドウで
    2 つの保存エントリが同じ物理ウィンドウを選び、後者が前者の位置を上書きする
  - 対処: 復元ループで割り当て済みウィンドウの `Set` を持ち回し、候補から除外する

### ✅ 7.2 AXValue 強制キャストの堅牢化（クラッシュ耐性）

- [x] `closestWindow` の `ref! as! AXValue` を条件付きキャストに変更
  - 現状: アプリが想定外の型を返すとクラッシュする
  - 対処: `guard let axVal = ref as? AXValue else { continue }` に変更（ロジック不変・堅牢化）

---

## Phase 8: 設定の実機能化・幽霊機能の整理（コンセプト精査）

> 2026-06-13 のコンセプト精査。「最小・ローカル完結」に照らし、動作しない設定UI・デッドコードを整理し、実機能のみ接続した。

### ✅ 8.1 設定の実機能化（接続）

- [x] `restoreDelay` を `restoreWindows` の適用間隔に接続（ハードコードの `usleep(200_000)` を設定値参照に）
- [x] `excludedApps` を `fetchVisibleAppWindows` の保存フィルタに合成（所有者名で除外）

### ✅ 8.2 幽霊機能・デッドコードの削除

- [x] `SettingsWindow` から `autoRestore` / `detectDisplayChanges` を削除（実処理で未使用だった）
- [x] `LayoutSelector.showLayoutDetailsDialog` / `showLayoutListWindow` を削除（どこからも呼ばれないスタブ）
- [x] README の「セカンダリディスプレイにステータスアイコン」記述を削除（`SecondaryStatusIcons` 削除済みで虚偽）

### ✅ 8.3 ドキュメントのコンセプト整合

- [x] SPEC §3.3 設定を実際の `UserDefaults` キーに修正、§4 から未使用の `config.json` を削除
- [x] SPEC §12 を「スコープ外（意図的に実装しない）」に書き換え
- [x] CLAUDE.md に設定の接続先と「やってはいけないこと」を追記
- [x] docs から旧 Rust / FFI / SPM 時代の記載を一掃（SPEC・DESIGN・本書）
