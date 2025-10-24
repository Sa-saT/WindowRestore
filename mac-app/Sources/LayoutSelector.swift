//! LayoutSelector.swift - レイアウト選択UI
//! レイアウト選択UI
//! レイアウト一覧表示UI、レイアウト選択・削除インターフェース

import Cocoa
import Foundation
import window_restore

/// レイアウトセレクターのデリゲートプロトコル
/// レイアウト選択のイベントを処理
protocol LayoutSelectorDelegate: AnyObject {
    /// レイアウトが選択された
    /// 引数: name - 選択されたレイアウト名
    func layoutSelected(name: String)
    
    /// レイアウトが削除された
    /// 引数: name - 削除されたレイアウト名
    func layoutDeleted(name: String)
}

/// レイアウト選択UI
/// レイアウト一覧表示UI、レイアウト選択・削除インターフェース
class LayoutSelector {
    
    // MARK: - プロパティ
    
    /// デリゲート
    weak var delegate: LayoutSelectorDelegate?
    
    /// レイアウト一覧（キャッシュ）
    private var layoutList: [LayoutInfo] = []
    
    /// レイアウト一覧の最終更新時刻
    private var lastUpdateTime: Date = Date.distantPast
    
    /// レイアウト一覧の更新間隔（秒）
    private let updateInterval: TimeInterval = 5.0
    
    // MARK: - データ構造
    
    /// レイアウト情報
    struct LayoutInfo {
        /// レイアウト名
        let name: String
        
        /// 作成日時
        let createdAt: Date
        
        /// 更新日時
        let updatedAt: Date
        
        /// ウィンドウ数
        let windowCount: Int
        
        /// レイアウトの説明
        let description: String
    }
    
    // MARK: - 初期化
    
    /// デフォルトイニシャライザ
    init() {
        print("LayoutSelectorが初期化されました")
    }
    
    // MARK: - レイアウト一覧管理
    
    /// レイアウト一覧を更新
    /// 保存されたレイアウトの一覧を取得して更新
    func updateLayoutList() {
        // 更新間隔をチェック
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) < updateInterval {
            return
        }
        
        print("レイアウト一覧を更新中...")
        
        // Rust関数を呼び出してレイアウト一覧を取得
        let layoutListPtr = get_layout_list()
        
        if layoutListPtr == nil {
            print("レイアウト一覧の取得に失敗しました")
            return
        }
        
        // C文字列をSwift文字列に変換
        let layoutListString = String(cString: layoutListPtr!)
        
        // メモリを解放
        free_string(layoutListPtr!)
        
        // JSON文字列をパース
        if let data = layoutListString.data(using: .utf8) {
            do {
                let layouts = try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
                self.layoutList = layouts.map { name in
                    LayoutInfo(
                        name: name,
                        createdAt: Date(), // TODO: 実際の作成日時を取得
                        updatedAt: Date(), // TODO: 実際の更新日時を取得
                        windowCount: 0,    // TODO: 実際のウィンドウ数を取得
                        description: "レイアウト「\(name)」"
                    )
                }
                lastUpdateTime = now
                print("レイアウト一覧を更新しました: \(layouts.count)個のレイアウト")
            } catch {
                print("レイアウト一覧のパースに失敗しました: \(error)")
            }
        }
    }
    
    /// レイアウト一覧を取得
    /// 戻り値: レイアウト情報の配列
    func getLayoutList() -> [LayoutInfo] {
        return layoutList
    }
    
    /// レイアウト選択ダイアログを表示
    /// ユーザーにレイアウトを選択してもらうダイアログを表示
    func showLayoutSelectionDialog() {
        print("レイアウト選択ダイアログを表示中...")
        
        // レイアウト一覧を更新
        updateLayoutList()
        
        if layoutList.isEmpty {
            showNoLayoutDialog()
            return
        }
        
        // レイアウト選択ダイアログを作成
        let alert = NSAlert()
        alert.messageText = "レイアウトを選択"
        alert.informativeText = "復元するレイアウトを選択してください："
        alert.addButton(withTitle: "復元")
        alert.addButton(withTitle: "キャンセル")
        
        // レイアウト一覧のポップアップボタンを作成
        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        popupButton.addItems(withTitles: layoutList.map { $0.name })
        alert.accessoryView = popupButton
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let selectedLayout = popupButton.selectedItem?.title ?? ""
            if !selectedLayout.isEmpty {
                delegate?.layoutSelected(name: selectedLayout)
            }
        }
    }
    
    /// レイアウト削除ダイアログを表示
    /// ユーザーにレイアウトの削除を確認するダイアログを表示
    func showLayoutDeletionDialog() {
        print("レイアウト削除ダイアログを表示中...")
        
        // レイアウト一覧を更新
        updateLayoutList()
        
        if layoutList.isEmpty {
            showNoLayoutDialog()
            return
        }
        
        // レイアウト削除ダイアログを作成
        let alert = NSAlert()
        alert.messageText = "レイアウトを削除"
        alert.informativeText = "削除するレイアウトを選択してください："
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning
        
        // レイアウト一覧のポップアップボタンを作成
        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        popupButton.addItems(withTitles: layoutList.map { $0.name })
        alert.accessoryView = popupButton
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let selectedLayout = popupButton.selectedItem?.title ?? ""
            if !selectedLayout.isEmpty {
                // 削除確認ダイアログを表示
                showDeletionConfirmationDialog(layoutName: selectedLayout)
            }
        }
    }
    
    /// 削除確認ダイアログを表示
    /// 引数: layoutName - 削除するレイアウト名
    private func showDeletionConfirmationDialog(layoutName: String) {
        let alert = NSAlert()
        alert.messageText = "レイアウトを削除"
        alert.informativeText = "レイアウト「\(layoutName)」を削除しますか？この操作は取り消せません。"
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            delegate?.layoutDeleted(name: layoutName)
        }
    }
    
    /// レイアウトなしダイアログを表示
    /// 保存されたレイアウトがない場合のダイアログを表示
    private func showNoLayoutDialog() {
        let alert = NSAlert()
        alert.messageText = "レイアウトがありません"
        alert.informativeText = "保存されたレイアウトがありません。まずレイアウトを保存してください。"
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        alert.runModal()
    }
    
    // MARK: - レイアウト詳細表示
    
    /// レイアウト詳細ダイアログを表示
    /// 引数: layoutName - 表示するレイアウト名
    func showLayoutDetailsDialog(layoutName: String) {
        print("レイアウト詳細ダイアログを表示中: \(layoutName)")
        
        // TODO: レイアウトの詳細情報を取得
        let alert = NSAlert()
        alert.messageText = "レイアウト詳細"
        alert.informativeText = "レイアウト「\(layoutName)」の詳細情報を表示します。"
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        alert.runModal()
    }
    
    /// レイアウト一覧ウィンドウを表示
    /// レイアウト一覧を表示する専用ウィンドウを開く
    func showLayoutListWindow() {
        print("レイアウト一覧ウィンドウを表示中...")
        
        // TODO: レイアウト一覧ウィンドウの実装
        let alert = NSAlert()
        alert.messageText = "レイアウト一覧"
        alert.informativeText = "レイアウト一覧ウィンドウは今後実装予定です。"
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        alert.runModal()
    }
    
    // MARK: - ヘルパーメソッド
    
    /// レイアウト名の検証
    /// 引数: name - 検証するレイアウト名
    /// 戻り値: 有効な場合true
    func validateLayoutName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空文字チェック
        if trimmedName.isEmpty {
            return false
        }
        
        // 長さチェック（最大50文字）
        if trimmedName.count > 50 {
            return false
        }
        
        // 無効な文字チェック
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        if trimmedName.rangeOfCharacter(from: invalidCharacters) != nil {
            return false
        }
        
        return true
    }
    
    /// レイアウト名の正規化
    /// 引数: name - 正規化するレイアウト名
    /// 戻り値: 正規化されたレイアウト名
    func normalizeLayoutName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 無効な文字を置換
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let normalizedName = trimmedName.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        // 長さを制限
        if normalizedName.count > 50 {
            let index = normalizedName.index(normalizedName.startIndex, offsetBy: 50)
            return String(normalizedName[..<index])
        }
        
        return normalizedName
    }
    
    /// レイアウト一覧を強制更新
    /// キャッシュを無視してレイアウト一覧を更新
    func forceUpdateLayoutList() {
        print("レイアウト一覧を強制更新中...")
        
        lastUpdateTime = Date.distantPast
        updateLayoutList()
        
        print("レイアウト一覧の強制更新が完了しました")
    }
    
    /// レイアウト一覧の更新間隔を設定
    /// 引数: interval - 更新間隔（秒）
    func setUpdateInterval(_ interval: TimeInterval) {
        print("レイアウト一覧の更新間隔を設定中: \(interval)秒")
        
        // 更新間隔を設定（次回更新時に適用）
        // 現在は固定値を使用
    }
}
