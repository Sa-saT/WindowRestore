//! AppDelegate.swift - macOSアプリケーションのメインエントリーポイント
//! macOSアプリケーションのメインエントリーポイント
//! アプリケーションのライフサイクル管理とメニューバー常駐機能を提供

import Cocoa
import Foundation
import window_restore

/// メインアプリケーションデリゲート
/// アプリケーションのライフサイクルとメニューバー常駐機能を管理
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - プロパティ
    
    /// ステータスバーアイテム（メニューバー常駐アイコン）
    private var statusBarItem: NSStatusItem?
    
    /// メニューコントローラー
    private var menuController: MenuController?
    
    /// 権限マネージャー
    private var permissionManager: PermissionManager?
    
    /// レイアウトセレクター
    private var layoutSelector: LayoutSelector?
    
    /// 設定ウィンドウ
    private var settingsWindow: SettingsWindow?
    
    /// アプリケーションの設定
    private var appSettings: AppSettings
    
    // MARK: - 初期化
    
    /// デフォルトイニシャライザ
    override init() {
        self.appSettings = AppSettings()
        super.init()
    }
    
    // MARK: - NSApplicationDelegate
    
    /// アプリケーション起動時の処理
    /// メニューバーアイテムの作成と初期設定を行う
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Window Restore アプリケーションが起動しました")
        
        // Rustライブラリの初期化
        initializeRustLibrary()
        
        // メニューバーアイテムの作成
        setupStatusBarItem()
        
        // メニューコントローラーの初期化
        setupMenuController()
        
        // 権限マネージャーの初期化
        setupPermissionManager()
        
        // レイアウトセレクターの初期化
        setupLayoutSelector()
        
        // 権限チェック
        checkInitialPermissions()
        
        // アプリケーションをバックグラウンドで実行
        NSApp.setActivationPolicy(.accessory)
        
        print("Window Restore の初期化が完了しました")
    }
    
    /// アプリケーション終了時の処理
    func applicationWillTerminate(_ notification: Notification) {
        print("Window Restore アプリケーションが終了します")
        
        // Rustライブラリのクリーンアップ
        cleanupRustLibrary()
        
        // ステータスバーアイテムの削除
        if let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
        
        print("Window Restore のクリーンアップが完了しました")
    }
    
    // MARK: - 初期設定メソッド
    
    /// Rustライブラリの初期化
    /// FFIを通じてRustライブラリを初期化
    private func initializeRustLibrary() {
        print("Rustライブラリを初期化中...")
        
        // Rustライブラリの初期化関数を呼び出し
        let result = init_library()
        
        if result == ERROR_SUCCESS {
            print("Rustライブラリの初期化が成功しました")
        } else {
            let msg = rustLastError()
            print("Rustライブラリの初期化に失敗しました: \(result) - \(msg)")
            showErrorNotification(title: "初期化エラー", message: msg.isEmpty ? "Rustライブラリの初期化に失敗しました" : msg)
        }
    }
    
    /// Rustライブラリのクリーンアップ
    /// FFIを通じてRustライブラリをクリーンアップ
    private func cleanupRustLibrary() {
        print("Rustライブラリをクリーンアップ中...")
        
        // Rustライブラリのクリーンアップ関数を呼び出し
        cleanup_library()
        
        print("Rustライブラリのクリーンアップが完了しました")
    }
    
    /// ステータスバーアイテムの設定
    /// メニューバーに常駐するアイコンを作成
    private func setupStatusBarItem() {
        print("ステータスバーアイテムを設定中...")
        
        // ステータスバーアイテムを作成
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusBarItem = statusBarItem else {
            print("ステータスバーアイテムの作成に失敗しました")
            return
        }
        
        // アイコンの設定
        if let button = statusBarItem.button {
            // カスタムアイコンを試みる（存在しない場合はプログラムで作成）
            if let customIcon = NSImage(named: "MenuBarIcon") {
                button.image = customIcon
                button.image?.isTemplate = true
            } else {
                // プログラマティックにアイコンを作成
                button.image = createMenuBarIcon()
                button.image?.isTemplate = true
            }
            button.toolTip = "Window Restore - ウィンドウレイアウト管理"
        }
        
        print("ステータスバーアイテムの設定が完了しました")
    }
    
    /// メニューバーアイコンをプログラマティックに作成
    /// シンプルなウィンドウグリッドアイコンを描画
    /// - Returns: メニューバー用のNSImage
    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 背景を透明に
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        // 2x2のウィンドウグリッドを描画
        let lineWidth: CGFloat = 1.5
        let padding: CGFloat = 2.0
        let gridSize = size.width - (padding * 2)
        let cellSize = gridSize / 2
        
        // 描画色を設定（テンプレート画像として使用するため黒）
        NSColor.black.setStroke()
        
        // 4つの小さな四角形を描画（2x2グリッド）
        for row in 0..<2 {
            for col in 0..<2 {
                let x = padding + (cellSize * CGFloat(col)) + (lineWidth / 2)
                let y = padding + (cellSize * CGFloat(row)) + (lineWidth / 2)
                let w = cellSize - lineWidth
                let h = cellSize - lineWidth
                
                let rect = NSRect(x: x, y: y, width: w, height: h)
                let path = NSBezierPath(rect: rect)
                path.lineWidth = lineWidth
                path.stroke()
            }
        }
        
        image.unlockFocus()
        
        return image
    }
    
    /// メニューコントローラーの設定
    /// メニューバーのドロップダウンメニューを管理
    private func setupMenuController() {
        print("メニューコントローラーを設定中...")
        
        menuController = MenuController(statusBarItem: statusBarItem)
        menuController?.delegate = self
        
        print("メニューコントローラーの設定が完了しました")
    }
    
    /// 権限マネージャーの設定
    /// アクセシビリティ権限の管理
    private func setupPermissionManager() {
        print("権限マネージャーを設定中...")
        
        permissionManager = PermissionManager()
        permissionManager?.delegate = self
        
        print("権限マネージャーの設定が完了しました")
    }
    
    /// レイアウトセレクターの設定
    /// レイアウトの選択と管理
    private func setupLayoutSelector() {
        print("レイアウトセレクターを設定中...")
        
        layoutSelector = LayoutSelector()
        layoutSelector?.delegate = self
        
        print("レイアウトセレクターの設定が完了しました")
    }
    
    /// 初期権限チェック
    /// アプリケーション起動時の権限状態を確認
    private func checkInitialPermissions() {
        print("初期権限チェックを実行中...")
        
        guard let permissionManager = permissionManager else {
            print("権限マネージャーが初期化されていません")
            return
        }
        
        // アクセシビリティ権限をチェック
        let hasPermission = permissionManager.checkAccessibilityPermission()
        
        if !hasPermission {
            print("アクセシビリティ権限がありません")
            showPermissionRequiredNotification()
        } else {
            print("アクセシビリティ権限が確認されました")
        }
    }
    
    // MARK: - 通知メソッド
    
    /// エラー通知の表示
    /// 引数: title - 通知タイトル、message - 通知メッセージ
    private func showErrorNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    /// 権限要求通知の表示
    /// アクセシビリティ権限が必要であることをユーザーに通知
    private func showPermissionRequiredNotification() {
        let notification = NSUserNotification()
        notification.title = "アクセシビリティ権限が必要です"
        notification.informativeText = "Window Restoreを使用するには、システム環境設定でアクセシビリティ権限を有効にしてください。"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - MenuControllerDelegate

/// メニューコントローラーのデリゲート
/// メニュー操作のイベントを処理
extension AppDelegate: MenuControllerDelegate {
    
    /// 現在のレイアウトを保存
    /// 引数: name - 保存するレイアウト名
    func saveCurrentLayout(name: String) {
        print("レイアウトを保存中: \(name)")
        
        // Rust関数を呼び出してレイアウトを保存
        let result = save_current_layout(name)
        
        if result == ERROR_SUCCESS {
            print("レイアウトの保存が成功しました: \(name)")
            showSuccessNotification(title: "保存完了", message: "レイアウト「\(name)」が保存されました")
        } else {
            let msg = rustLastError()
            print("レイアウトの保存に失敗しました: \(result) - \(msg)")
            showErrorNotification(title: "保存エラー", message: msg.isEmpty ? "レイアウトの保存に失敗しました" : msg)
        }
    }
    
    /// レイアウトを復元
    /// 引数: name - 復元するレイアウト名
    func restoreLayout(name: String) {
        print("レイアウトを復元中: \(name)")
        
        // Rust関数を呼び出してレイアウトを復元
        let result = restore_layout(name)
        
        if result == ERROR_SUCCESS {
            print("レイアウトの復元が成功しました: \(name)")
            showSuccessNotification(title: "復元完了", message: "レイアウト「\(name)」が復元されました")
        } else {
            let msg = rustLastError()
            print("レイアウトの復元に失敗しました: \(result) - \(msg)")
            showErrorNotification(title: "復元エラー", message: msg.isEmpty ? "レイアウトの復元に失敗しました" : msg)
        }
    }
    
    /// レイアウトを削除
    /// 引数: name - 削除するレイアウト名
    func deleteLayout(name: String) {
        print("レイアウトを削除中: \(name)")
        
        // Rust関数を呼び出してレイアウトを削除
        let result = delete_layout(name)
        
        if result == ERROR_SUCCESS {
            print("レイアウトの削除が成功しました: \(name)")
            showSuccessNotification(title: "削除完了", message: "レイアウト「\(name)」が削除されました")
        } else {
            let msg = rustLastError()
            print("レイアウトの削除に失敗しました: \(result) - \(msg)")
            showErrorNotification(title: "削除エラー", message: msg.isEmpty ? "レイアウトの削除に失敗しました" : msg)
        }
    }
    
    /// 設定画面を表示
    func showSettings() {
        print("設定画面を表示中...")
        
        // 設定ウィンドウが未作成の場合は作成
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.settingsDelegate = self
        }
        
        // 設定ウィンドウを表示
        settingsWindow?.show()
    }
    
    /// アプリケーションを終了
    func quitApplication() {
        print("アプリケーションを終了中...")
        NSApplication.shared.terminate(nil)
    }
    
    /// 成功通知の表示
    /// 引数: title - 通知タイトル、message - 通知メッセージ
    private func showSuccessNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    /// 情報通知の表示
    /// 引数: title - 通知タイトル、message - 通知メッセージ
    private func showInfoNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - PermissionManagerDelegate

/// 権限マネージャーのデリゲート
/// 権限状態の変更を処理
extension AppDelegate: PermissionManagerDelegate {
    
    /// 権限状態が変更された
    /// 引数: hasPermission - 権限があるかどうか
    func permissionStatusChanged(hasPermission: Bool) {
        print("権限状態が変更されました: \(hasPermission)")
        
        if hasPermission {
            showSuccessNotification(title: "権限取得", message: "アクセシビリティ権限が取得されました")
        } else {
            showPermissionRequiredNotification()
        }
    }
}

// MARK: - LayoutSelectorDelegate

/// レイアウトセレクターのデリゲート
/// レイアウト選択のイベントを処理
extension AppDelegate: LayoutSelectorDelegate {
    
    /// レイアウトが選択された
    /// 引数: name - 選択されたレイアウト名
    func layoutSelected(name: String) {
        print("レイアウトが選択されました: \(name)")
        restoreLayout(name: name)
    }
    
    /// レイアウトが削除された
    /// 引数: name - 削除されたレイアウト名
    func layoutDeleted(name: String) {
        print("レイアウトが削除されました: \(name)")
        deleteLayout(name: name)
    }
}

/// 設定ウィンドウのデリゲート
/// 設定変更のイベントを処理
extension AppDelegate: SettingsWindowDelegate {
    
    /// 設定が変更された
    func settingsDidChange() {
        print("設定が変更されました")
        showSuccessNotification(title: "設定保存", message: "設定が正常に保存されました")
    }
}

// MARK: - アプリケーション設定

/// アプリケーションの設定を管理
struct AppSettings {
    /// アプリケーション名
    let appName = "Window Restore"
    
    /// アプリケーションのバージョン
    let version = "1.0.0"
    
    /// デフォルトの復元間隔（ミリ秒）
    let defaultRestoreDelayMs: UInt64 = 1000
    
    /// デフォルトの最大リトライ回数
    let defaultMaxRetryAttempts: UInt32 = 3
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
