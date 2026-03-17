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

        // レイアウトエンジンの初期化
        initializeLayoutEngine()
        
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
        
        // LSUIElement=true (Info.plist) により起動時からアクセサリアプリとして動作。
        // ここで setActivationPolicy(.accessory) を呼ぶとステータスバーアイテムが
        // リセットされるため呼ばない。
        
        print("Window Restore の初期化が完了しました")
    }
    
    /// アプリケーション終了時の処理
    func applicationWillTerminate(_ notification: Notification) {
        print("Window Restore アプリケーションが終了します")
        
        // レイアウトエンジンのクリーンアップ
        cleanupLayoutEngine()
        
        // ステータスバーアイテムの削除
        if let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
        
        print("Window Restore のクリーンアップが完了しました")
    }
    
    // MARK: - 初期設定メソッド
    
    private func initializeLayoutEngine() {
        print("レイアウトエンジンを初期化中...")
        let initResult = LayoutAPI.initLibrary()
        switch initResult {
        case .success:
            print("レイアウトエンジンの初期化が成功しました")
        case .failure(let code, let message):
            print("レイアウトエンジンの初期化に失敗しました: \(code) - \(message)")
            showErrorNotification(title: "初期化エラー", message: message)
        }
    }
    
    private func cleanupLayoutEngine() {
        print("レイアウトエンジンをクリーンアップ中...")
        LayoutAPI.cleanupLibrary()
        print("レイアウトエンジンのクリーンアップが完了しました")
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
        
        // アイコンの設定（createMenuBarIcon 内で isTemplate 設定済み）
        if let button = statusBarItem.button {
            button.image = createMenuBarIcon()
            button.toolTip = "Window Restore - ウィンドウレイアウト管理"
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            statusBarItem.length = NSStatusItem.squareLength
        }
        
        print("ステータスバーアイテムの設定が完了しました")
    }
    
    

    /// メニューバーアイコンを生成する。
    /// アプリアイコン（Assets.xcassets/AppIcon）をメニューバーサイズ(18pt)にリサイズして返す。
    /// テンプレートモードにより macOS がダーク/ライトモードを自動で制御する。
    /// アプリアイコンが取得できない場合は createDogMenuBarIcon() にフォールバック。
    private func createMenuBarIcon() -> NSImage {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            return image
        }
        return createDogMenuBarIcon()
    }

    /// 犬アイコン（四角枠＋DOGテキスト）を描画して返す（フォールバック用）
    private func createDogMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        // lockFocus() は起動直後に描画コンテキストが未確立だと失敗するため
        // drawingHandler ベースの遅延描画を使用する
        let image = NSImage(size: size, flipped: false) { _ in
            let padding: CGFloat = 0.6
            let rect = NSRect(x: padding, y: padding, width: size.width - padding * 2, height: size.height - padding * 2)

            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            NSColor.black.setStroke()
            path.lineWidth = 1.0
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let font = NSFont(name: "HelveticaNeue-CondensedBold", size: 9.5)
                ?? NSFont.systemFont(ofSize: 9.0, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph,
                .kern: -0.6
            ]
            let text = "Dog" as NSString
            let textRect = rect.insetBy(dx: 1.0, dy: 1.8)
            text.draw(in: textRect, withAttributes: attrs)
            return true
        }
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
    
    /// 現在のレイアウトを保存（スマート統合版）
    /// 物理ディスプレイを自動検出し、仮想Spaceの追加保存も案内する
    func saveCurrentLayout(name: String) {
        print("レイアウトを保存中: \(name)")

        // 既存ファイルがある場合は上書き確認
        if WindowManager.shared.layoutExists(name: name) {
            let confirm = NSAlert()
            confirm.messageText = "「\(name)」は既に存在します"
            confirm.informativeText = "上書きして最初から保存し直しますか？"
            confirm.addButton(withTitle: "上書きして保存")
            confirm.addButton(withTitle: "キャンセル")
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
            try? WindowManager.shared.deleteLayout(name: name)
        }

        let screenCount = NSScreen.screens.count
        var spaceIndex = 1

        repeat {
            let label = "Space\(spaceIndex)"

            // 現在の全ディスプレイのウィンドウを一括キャプチャして保存
            do {
                try WindowManager.shared.saveWindowsAppend(name: name, label: label)
            } catch {
                showErrorNotification(title: "保存エラー", message: error.localizedDescription)
                return
            }

            // 保存件数をカウント
            let savedCount = (try? WindowManager.shared.loadWindows(name: name))
                .map { $0.filter { $0.layoutLabel == label }.count } ?? 0
            let displayText = screenCount > 1 ? "\(screenCount)台のディスプレイ・" : ""

            print("保存完了: \(name) - \(label) (\(savedCount)件)")

            // 他のSpaceも保存するか確認
            let nextAlert = NSAlert()
            nextAlert.messageText = "\(label) を保存しました"
            nextAlert.informativeText = """
                \(displayText)\(savedCount)個のウィンドウを記録しました。

                他にも保存するSpaceがありますか？
                仮想Spaceがある場合、切り替えて追加保存できます。
                """
            nextAlert.addButton(withTitle: "次のSpaceを保存")
            nextAlert.addButton(withTitle: "保存完了")
            guard nextAlert.runModal() == .alertFirstButtonReturn else { break }

            // Space切替を案内
            let switchAlert = NSAlert()
            switchAlert.messageText = "Spaceを切り替えてください"
            switchAlert.informativeText = "Space\(spaceIndex + 1) を保存します。\n対象のSpaceに切り替えたら「準備完了」を押してください。"
            switchAlert.addButton(withTitle: "準備完了")
            switchAlert.addButton(withTitle: "キャンセル")
            guard switchAlert.runModal() == .alertFirstButtonReturn else { break }

            spaceIndex += 1
        } while true

        let spaceText = spaceIndex > 1 ? "（\(spaceIndex) Space）" : ""
        showSuccessNotification(title: "保存完了", message: "レイアウト「\(name)」を保存しました\(spaceText)")
    }
    
    /// レイアウトを復元（統合一括版）
    /// ラベル有無にかかわらず全エントリを一括復元。AX API は Space を横断するため Space 切替不要。
    func restoreLayout(name: String) {
        print("レイアウトを復元中: \(name)")
        let result = LayoutAPI.restoreLayout(name: name)
        switch result {
        case .success:
            print("レイアウトの復元が成功しました: \(name)")
            showSuccessNotification(title: "復元完了", message: "レイアウト「\(name)」を復元しました")
        case .failure(_, let message):
            print("レイアウトの復元に失敗しました: \(message)")
            showErrorNotification(title: "復元エラー", message: message)
        }
    }
    
    /// レイアウトを削除
    /// 引数: name - 削除するレイアウト名
    func deleteLayout(name: String) {
        print("レイアウトを削除中: \(name)")
        
        // レイアウトを削除
        let result = LayoutAPI.deleteLayout(name: name)
        
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
