//! MenuController.swift - メニューバー常駐UI
//! メニューバー常駐UI
//! ドロップダウンメニューの管理とメニュー項目の実装

import Cocoa
import Foundation
import window_restore

/// メニューコントローラーのデリゲートプロトコル
/// メニュー操作のイベントを処理
protocol MenuControllerDelegate: AnyObject {
    /// 現在のレイアウトを保存
    /// 引数: name - 保存するレイアウト名
    func saveCurrentLayout(name: String)
    
    /// レイアウトを復元
    /// 引数: name - 復元するレイアウト名
    func restoreLayout(name: String)
    
    /// レイアウトを削除
    /// 引数: name - 削除するレイアウト名
    func deleteLayout(name: String)
    
    /// 設定画面を表示
    func showSettings()
    
    /// アプリケーションを終了
    func quitApplication()
}

/// メニューバー常駐UIのコントローラー
/// ドロップダウンメニューの管理とメニュー項目の実装
class MenuController {
    
    // MARK: - プロパティ
    
    /// デリゲート
    weak var delegate: MenuControllerDelegate?
    
    /// ステータスバーアイテム
    private let statusBarItem: NSStatusItem?
    
    /// メインメニュー
    private var mainMenu: NSMenu?
    
    /// レイアウト一覧メニュー
    private var layoutMenu: NSMenu?
    
    /// レイアウト一覧（キャッシュ）
    private var layoutList: [String] = []
    
    /// レイアウト一覧の最終更新時刻
    private var lastLayoutUpdate: Date = Date.distantPast
    
    /// レイアウト一覧の更新間隔（秒）
    private let layoutUpdateInterval: TimeInterval = 5.0
    
    // MARK: - 初期化
    
    /// イニシャライザ
    /// 引数: statusBarItem - ステータスバーアイテム
    init(statusBarItem: NSStatusItem?) {
        self.statusBarItem = statusBarItem
        setupMainMenu()
    }
    
    // MARK: - メニュー設定
    
    /// メインメニューの設定
    /// ドロップダウンメニューの基本構造を作成
    private func setupMainMenu() {
        guard let statusBarItem = statusBarItem else {
            print("ステータスバーアイテムが設定されていません")
            return
        }
        
        // メインメニューを作成
        mainMenu = NSMenu()
        
        // メニュー項目を追加
        addSaveLayoutMenuItem()
        addRestoreLayoutMenuItem()
        addLayoutListMenuItem()
        addSeparatorMenuItem()
        addSettingsMenuItem()
        addQuitMenuItem()
        
        // ステータスバーアイテムにメニューを設定
        statusBarItem.menu = mainMenu
        
        print("メインメニューの設定が完了しました")
    }
    
    /// レイアウト保存メニュー項目の追加
    /// 現在のレイアウトを保存するメニュー項目を作成
    private func addSaveLayoutMenuItem() {
        let saveItem = NSMenuItem(title: "💾 現在のレイアウトを保存", action: #selector(saveCurrentLayout), keyEquivalent: "")
        saveItem.target = self
        saveItem.toolTip = "現在開いているウィンドウの配置を保存します"
        
        mainMenu?.addItem(saveItem)
    }
    
    /// レイアウト復元メニュー項目の追加
    /// レイアウトを復元するメニュー項目を作成
    private func addRestoreLayoutMenuItem() {
        let restoreItem = NSMenuItem(title: "🔁 レイアウトを復元", action: #selector(showRestoreDialog), keyEquivalent: "")
        restoreItem.target = self
        restoreItem.toolTip = "保存されたレイアウトを復元します"
        
        mainMenu?.addItem(restoreItem)
    }
    
    /// レイアウト一覧メニュー項目の追加
    /// 保存されたレイアウトの一覧を表示するメニュー項目を作成
    private func addLayoutListMenuItem() {
        let layoutListItem = NSMenuItem(title: "📂 レイアウト一覧", action: nil, keyEquivalent: "")
        
        // サブメニューを作成
        layoutMenu = NSMenu()
        layoutListItem.submenu = layoutMenu
        
        // レイアウト一覧を更新
        updateLayoutList()
        
        mainMenu?.addItem(layoutListItem)
    }
    
    /// 区切り線メニュー項目の追加
    /// メニュー項目を視覚的に分離する区切り線を追加
    private func addSeparatorMenuItem() {
        mainMenu?.addItem(NSMenuItem.separator())
    }
    
    /// 設定メニュー項目の追加
    /// アプリケーションの設定を開くメニュー項目を作成
    private func addSettingsMenuItem() {
        let settingsItem = NSMenuItem(title: "⚙️ 設定", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.toolTip = "アプリケーションの設定を開きます"
        
        mainMenu?.addItem(settingsItem)
    }
    
    /// 終了メニュー項目の追加
    /// アプリケーションを終了するメニュー項目を作成
    private func addQuitMenuItem() {
        let quitItem = NSMenuItem(title: "🚪 終了", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        quitItem.toolTip = "アプリケーションを終了します"
        
        mainMenu?.addItem(quitItem)
    }
    
    // MARK: - レイアウト一覧管理
    
    /// レイアウト一覧の更新
    /// 保存されたレイアウトの一覧を取得してメニューを更新
    func updateLayoutList() {
        // 更新間隔をチェック
        let now = Date()
        if now.timeIntervalSince(lastLayoutUpdate) < layoutUpdateInterval {
            return
        }
        
        print("レイアウト一覧を更新中...")
        
        // Rust関数を呼び出してレイアウト一覧を取得
        let result = RustAPI.listLayouts()
        switch result {
        case .success(let layouts):
            self.layoutList = layouts
            updateLayoutMenu()
            lastLayoutUpdate = now
            print("レイアウト一覧を更新しました: \(layouts.count)個のレイアウト")
        case .failure(_, let message):
            print("レイアウト一覧の取得に失敗しました: \(message)")
        }
    }
    
    /// レイアウトメニューの更新
    /// レイアウト一覧に基づいてメニュー項目を更新
    private func updateLayoutMenu() {
        guard let layoutMenu = layoutMenu else { return }
        
        // 既存のメニュー項目をクリア
        layoutMenu.removeAllItems()
        
        if layoutList.isEmpty {
            let noLayoutItem = NSMenuItem(title: "レイアウトがありません", action: nil, keyEquivalent: "")
            noLayoutItem.isEnabled = false
            layoutMenu.addItem(noLayoutItem)
        } else {
            // 各レイアウトのメニュー項目を作成
            for layoutName in layoutList {
                let layoutItem = NSMenuItem(title: layoutName, action: #selector(restoreLayout(_:)), keyEquivalent: "")
                layoutItem.target = self
                layoutItem.representedObject = layoutName
                layoutItem.toolTip = "レイアウト「\(layoutName)」を復元します"
                
                layoutMenu.addItem(layoutItem)
                
                // 削除メニュー項目を追加
                let deleteItem = NSMenuItem(title: "🗑️ 削除", action: #selector(deleteLayout(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = layoutName
                deleteItem.toolTip = "レイアウト「\(layoutName)」を削除します"
                
                layoutMenu.addItem(deleteItem)
                
                // 区切り線を追加（最後の項目以外）
                if layoutName != layoutList.last {
                    layoutMenu.addItem(NSMenuItem.separator())
                }
            }
        }
    }
    
    // MARK: - アクション
    
    /// 現在のレイアウトを保存
    /// ユーザーにレイアウト名を入力してもらって保存
    @objc private func saveCurrentLayout() {
        print("現在のレイアウトを保存中...")
        
        // レイアウト名の入力ダイアログを表示
        let alert = NSAlert()
        alert.messageText = "レイアウトを保存"
        alert.informativeText = "保存するレイアウトの名前を入力してください："
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.placeholderString = "レイアウト名"
        alert.accessoryView = inputField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let layoutName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !layoutName.isEmpty {
                delegate?.saveCurrentLayout(name: layoutName)
                // レイアウト一覧を更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.updateLayoutList()
                }
            } else {
                showErrorAlert(title: "エラー", message: "レイアウト名を入力してください")
            }
        }
    }
    
    /// 復元ダイアログを表示
    /// レイアウトを復元するためのダイアログを表示
    @objc private func showRestoreDialog() {
        print("復元ダイアログを表示中...")
        
        if layoutList.isEmpty {
            showInfoAlert(title: "情報", message: "保存されたレイアウトがありません")
            return
        }
        
        // レイアウト選択ダイアログを表示
        let alert = NSAlert()
        alert.messageText = "レイアウトを復元"
        alert.informativeText = "復元するレイアウトを選択してください："
        alert.addButton(withTitle: "復元")
        alert.addButton(withTitle: "キャンセル")
        
        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 26))
        popupButton.addItems(withTitles: layoutList)
        alert.accessoryView = popupButton
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let selectedLayout = popupButton.selectedItem?.title ?? ""
            if !selectedLayout.isEmpty {
                delegate?.restoreLayout(name: selectedLayout)
            }
        }
    }
    
    /// レイアウトを復元
    /// 引数: sender - メニュー項目
    @objc private func restoreLayout(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        print("レイアウトを復元中: \(layoutName)")
        delegate?.restoreLayout(name: layoutName)
    }
    
    /// レイアウトを削除
    /// 引数: sender - メニュー項目
    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let layoutName = sender.representedObject as? String else { return }
        
        print("レイアウトを削除中: \(layoutName)")
        
        // 削除確認ダイアログを表示
        let alert = NSAlert()
        alert.messageText = "レイアウトを削除"
        alert.informativeText = "レイアウト「\(layoutName)」を削除しますか？この操作は取り消せません。"
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            delegate?.deleteLayout(name: layoutName)
            // レイアウト一覧を更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.updateLayoutList()
            }
        }
    }
    
    /// 設定画面を表示
    @objc private func showSettings() {
        print("設定画面を表示中...")
        delegate?.showSettings()
    }
    
    /// アプリケーションを終了
    @objc private func quitApplication() {
        print("アプリケーションを終了中...")
        delegate?.quitApplication()
    }
    
    // MARK: - ヘルパーメソッド
    
    /// エラーアラートを表示
    /// 引数: title - タイトル、message - メッセージ
    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// 情報アラートを表示
    /// 引数: title - タイトル、message - メッセージ
    private func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Rustエラーメッセージ取得ヘルパー

private func rustLastError() -> String {
    if let ptr = get_last_error_message() {
        let message = String(cString: ptr)
        free_string(ptr)
        return message
    }
    return ""
}
