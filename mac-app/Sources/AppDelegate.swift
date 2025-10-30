//! AppDelegate.swift - macOSアプリケーションのメインエントリーポイント
//! macOSアプリケーションのメインエントリーポイント
//! アプリケーションのライフサイクル管理とメニューバー常駐機能を提供

import Cocoa
import Foundation
import UserNotifications

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
        
        // 通知許可のリクエスト（初回のみ）
        requestUserNotificationPermission()

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
        let initResult = RustAPI.initLibrary()
        
        switch initResult {
        case .success:
            print("Rustライブラリの初期化が成功しました")
        case .failure(let code, let message):
            print("Rustライブラリの初期化に失敗しました: \(code) - \(message)")
            showErrorNotification(title: "初期化エラー", message: message)
        }
    }
    
    /// Rustライブラリのクリーンアップ
    /// FFIを通じてRustライブラリをクリーンアップ
    private func cleanupRustLibrary() {
        print("Rustライブラリをクリーンアップ中...")
        
        // Rustライブラリのクリーンアップ関数を呼び出し
        RustAPI.cleanupLibrary()
        
        print("Rustライブラリのクリーンアップが完了しました")
    }
    
    /// ステータスバーアイテムの設定
    /// メニューバーに常駐するアイコンを作成
    private func setupStatusBarItem() {
        print("ステータスバーアイテムを設定中...")
        
        // ステータスバーアイテムを作成（標準幅）
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusBarItem = statusBarItem else {
            print("ステータスバーアイテムの作成に失敗しました")
            return
        }
        
        // アイコンの設定
        if let button = statusBarItem.button {
            button.image = createDogMenuBarIcon()
            button.image?.isTemplate = true
            button.toolTip = "Window Restore - ウィンドウレイアウト管理"
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            statusBarItem.length = NSStatusItem.squareLength
        }
        
        print("ステータスバーアイテムの設定が完了しました")
    }
    
    

    /// 犬アイコン（四角枠＋DOGテキスト）を描画して返す
    private func createDogMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        // 背景透明
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        // 外枠（角丸）
        let padding: CGFloat = 0.6
        let rect = NSRect(x: padding, y: padding, width: size.width - padding * 2, height: size.height - padding * 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        NSColor.black.setStroke()
        path.lineWidth = 1.0
        path.stroke()

        // 『DOG』テキストを枠内中央に描画
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        // コンデンスド系フォントを優先
        let font = NSFont(name: "HelveticaNeue-CondensedBold", size: 9.5) ?? NSFont.systemFont(ofSize: 9.0, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
            .kern: -0.6
        ]
        let text = "Dog" as NSString
        let textRect = rect.insetBy(dx: 1.0, dy: 1.8)
        text.draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    /// Resources から DogIcon.(png|pdf|icns) をロード
    private func loadDogIconResource() -> NSImage? {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let candidates = [
            ("DogIcon", "png"),
            ("DogIcon", "pdf"),
            ("DogIcon", "icns")
        ]
        for (name, ext) in candidates {
            if let url = bundle.url(forResource: name, withExtension: ext), let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }

    /// 犬アイコン適用前にプレビューして確認
    private func promptAndApplyDogIcon() {
        guard let statusBarItem = statusBarItem, let button = statusBarItem.button else { return }
        let preview = createDogMenuBarIcon()

        let alert = NSAlert()
        alert.messageText = "メニューバーアイコンの変更"
        alert.informativeText = "四角い枠内に『DOG』と描いたアイコンに変更します。適用しますか？"
        alert.addButton(withTitle: "適用")
        alert.addButton(withTitle: "キャンセル")

        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
        imageView.image = preview
        imageView.imageScaling = .scaleProportionallyUpOrDown
        alert.accessoryView = imageView

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            button.image = preview
            button.image?.isTemplate = true
        }
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
        postUserNotification(title: title, body: message)
    }
    
    /// 権限要求通知の表示
    /// アクセシビリティ権限が必要であることをユーザーに通知
    private func showPermissionRequiredNotification() {
        postUserNotification(title: "アクセシビリティ権限が必要です", body: "システム設定で有効にしてください。")
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
        
        // 単一保存/マルチSpace保存の選択
        let choice = NSAlert()
        choice.messageText = "保存モードの選択"
        choice.informativeText = "複数のSpaceを連続して保存しますか？"
        choice.addButton(withTitle: "マルチSpace開始")
        choice.addButton(withTitle: "単一保存")
        choice.addButton(withTitle: "キャンセル")
        let resp = choice.runModal()

        if resp == .alertFirstButtonReturn {
            // マルチSpace保存フロー
            var index = 1
            var continueLoop = true
            while continueLoop {
                let baseLabel = "Space\(index)"
                var usedLabel = baseLabel
                // 重複ラベル検知
                if WindowManager.shared.hasLabel(name: name, label: baseLabel) {
                    let dup = NSAlert()
                    dup.messageText = "同じSpaceで保存しましたか？"
                    dup.informativeText = "ラベル \(baseLabel) は既に存在します。どうしますか？"
                    dup.addButton(withTitle: "置き換え")
                    dup.addButton(withTitle: "別名で保存")
                    dup.addButton(withTitle: "スキップ")
                    let d = dup.runModal()
                    if d == .alertFirstButtonReturn {
                        // 置き換え
                        let captured = WindowManager.shared.fetchVisibleAppWindows().map { w in
                            WindowInfo(ownerName: w.ownerName, pid: w.pid, windowName: w.windowName, bounds: w.bounds, displayUUID: w.displayUUID, spaceNumber: w.spaceNumber, layoutLabel: baseLabel)
                        }
                        do {
                            try WindowManager.shared.replaceWindowsForLabel(name: name, label: baseLabel, with: captured)
                            usedLabel = baseLabel
                            showInfoNotification(title: "保存", message: "\(baseLabel) を置き換えました。次のSpaceへ切り替えてください。")
                        } catch {
                            showErrorNotification(title: "保存エラー", message: error.localizedDescription)
                        }
                    } else if d == .alertSecondButtonReturn {
                        // 別名
                        let newLabel = WindowManager.shared.nextAvailableLabel(name: name, baseLabel: baseLabel)
                        do {
                            try WindowManager.shared.saveWindowsAppend(name: name, label: newLabel)
                            usedLabel = newLabel
                            showInfoNotification(title: "保存", message: "\(newLabel) を保存しました。次のSpaceへ切り替えてください。")
                        } catch {
                            showErrorNotification(title: "保存エラー", message: error.localizedDescription)
                        }
                    } else {
                        // スキップ
                        usedLabel = baseLabel
                        // 何もしない
                    }
                } else {
                    do {
                        try WindowManager.shared.saveWindowsAppend(name: name, label: baseLabel)
                        usedLabel = baseLabel
                        showInfoNotification(title: "保存", message: "\(baseLabel) を保存しました。次のSpaceへ切り替えてください。")
                    } catch {
                        showErrorNotification(title: "保存エラー", message: error.localizedDescription)
                    }
                }

                print("保存: \(name) - \(usedLabel)")

                // 次のSpaceに切り替えを促す
                let nextAlert = NSAlert()
                nextAlert.messageText = "次のSpaceに切り替えてください"
                nextAlert.informativeText = "Spaceを切り替えたら『次を取得』を押してください。すべて保存したら『完了』を押します。"
                nextAlert.addButton(withTitle: "次を取得")
                nextAlert.addButton(withTitle: "完了")
                nextAlert.addButton(withTitle: "キャンセル")
                let nextResp = nextAlert.runModal()
                if nextResp == .alertFirstButtonReturn {
                    index += 1
                    continueLoop = true
                } else if nextResp == .alertSecondButtonReturn {
                    continueLoop = false
                } else {
                    continueLoop = false
                }
            }
            showSuccessNotification(title: "保存完了", message: "レイアウト「\(name)」の保存が完了しました")
        } else if resp == .alertSecondButtonReturn {
            // 単一保存（現在のSpaceのみ）
            let result = RustAPI.saveLayout(name: name)
            switch result {
            case .success:
                print("レイアウトの保存が成功しました: \(name)")
                showSuccessNotification(title: "保存完了", message: "レイアウト「\(name)」が保存されました")
            case .failure(_, let message):
                print("レイアウトの保存に失敗しました: \(message)")
                showErrorNotification(title: "保存エラー", message: message)
            }
        } else {
            // キャンセル
            return
        }
    }
    
    /// レイアウトを復元
    /// 引数: name - 復元するレイアウト名
    func restoreLayout(name: String) {
        print("レイアウトを復元中: \(name)")
        
        // ラベル付きならインタラクティブ復元を提案
        let labels = WindowManager.shared.layoutLabels(in: name)
        if !labels.isEmpty {
            let alert = NSAlert()
            alert.messageText = "復元モードの選択"
            alert.informativeText = "ラベル付きのレイアウトが見つかりました。Spaceを切り替えながら順に復元しますか？"
            alert.addButton(withTitle: "一括復元")
            alert.addButton(withTitle: "インタラクティブ復元")
            alert.addButton(withTitle: "キャンセル")
            let resp = alert.runModal()
            if resp == .alertSecondButtonReturn {
                do {
                    try WindowManager.shared.restoreWindowsInteractive(name: name) { label in
                        let prompt = NSAlert()
                        prompt.messageText = "Space切替のお願い"
                        prompt.informativeText = "\(label) を復元します。対象のSpaceに切り替えたら『復元』を押してください。"
                        prompt.addButton(withTitle: "復元")
                        prompt.addButton(withTitle: "キャンセル")
                        let r = prompt.runModal()
                        return r == .alertFirstButtonReturn
                    }
                    showSuccessNotification(title: "復元完了", message: "レイアウト「\(name)」を復元しました")
                } catch {
                    showErrorNotification(title: "復元エラー", message: error.localizedDescription)
                }
                return
            } else if resp == .alertThirdButtonReturn {
                // キャンセル
                return
            }
        }

        // 通常の一括復元
        let result = RustAPI.restoreLayout(name: name)
        switch result {
        case .success:
            print("レイアウトの復元が成功しました: \(name)")
            showSuccessNotification(title: "復元完了", message: "レイアウト「\(name)」が復元されました")
        case .failure(_, let message):
            print("レイアウトの復元に失敗しました: \(message)")
            showErrorNotification(title: "復元エラー", message: message)
        }
    }
    
    /// レイアウトを削除
    /// 引数: name - 削除するレイアウト名
    func deleteLayout(name: String) {
        print("レイアウトを削除中: \(name)")
        
        // Rust関数を呼び出してレイアウトを削除
        let result = RustAPI.deleteLayout(name: name)
        
        switch result {
        case .success:
            print("レイアウトの削除が成功しました: \(name)")
            showSuccessNotification(title: "削除完了", message: "レイアウト「\(name)」が削除されました")
        case .failure(let code, let message):
            print("レイアウトの削除に失敗しました: \(code) - \(message)")
            showErrorNotification(title: "削除エラー", message: message)
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
        postUserNotification(title: title, body: message)
    }
    
    /// 情報通知の表示
    /// 引数: title - 通知タイトル、message - 通知メッセージ
    private func showInfoNotification(title: String, message: String) {
        postUserNotification(title: title, body: message)
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

// rustLastError は FFIHelpers.swift を使用

// MARK: - UserNotifications 簡易通知

private func requestUserNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            print("Notification permission error: \(error)")
        } else {
            print("Notification permission granted: \(granted)")
        }
    }
}

private func postUserNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Failed to post notification: \(error)")
        }
    }
}
