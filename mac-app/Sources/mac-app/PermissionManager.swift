//! PermissionManager.swift - 権限管理UI
//! 権限管理UI
//! アクセシビリティ権限のチェック、システム設定への誘導、権限状態の監視

import Cocoa
import Foundation
import window_restore

/// 権限マネージャーのデリゲートプロトコル
/// 権限状態の変更を処理
protocol PermissionManagerDelegate: AnyObject {
    /// 権限状態が変更された
    /// 引数: hasPermission - 権限があるかどうか
    func permissionStatusChanged(hasPermission: Bool)
}

/// 権限管理マネージャー
/// アクセシビリティ権限のチェック、システム設定への誘導、権限状態の監視
class PermissionManager {
    
    // MARK: - プロパティ
    
    /// デリゲート
    weak var delegate: PermissionManagerDelegate?
    
    /// 権限チェックタイマー
    private var permissionCheckTimer: Timer?
    
    /// 権限チェック間隔（秒）
    private let checkInterval: TimeInterval = 10.0
    
    /// 前回の権限状態
    private var lastPermissionStatus: Bool = false
    
    // MARK: - 初期化
    
    /// デフォルトイニシャライザ
    init() {
        // 初期権限状態を取得
        lastPermissionStatus = checkAccessibilityPermission()
        
        // 権限チェックタイマーを開始
        startPermissionMonitoring()
        
        print("PermissionManagerが初期化されました")
    }
    
    /// デイニシャライザ
    deinit {
        stopPermissionMonitoring()
        print("PermissionManagerが破棄されました")
    }
    
    // MARK: - 権限チェック
    
    /// アクセシビリティ権限をチェック
    /// 戻り値: 権限がある場合true
    func checkAccessibilityPermission() -> Bool {
        print("アクセシビリティ権限をチェック中...")
        
        // Rust関数を呼び出して権限をチェック
        let result = check_permissions()
        
        let hasPermission = (result == ERROR_SUCCESS)
        
        print("アクセシビリティ権限チェック結果: \(hasPermission)")
        
        return hasPermission
    }
    
    /// 権限状態の監視を開始
    /// 定期的に権限状態をチェックして変更を検知
    private func startPermissionMonitoring() {
        print("権限状態の監視を開始中...")
        
        // 既存のタイマーを停止
        stopPermissionMonitoring()
        
        // 新しいタイマーを作成
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkPermissionStatusChange()
        }
        
        print("権限状態の監視が開始されました")
    }
    
    /// 権限状態の監視を停止
    /// タイマーを停止して監視を終了
    private func stopPermissionMonitoring() {
        if let timer = permissionCheckTimer {
            timer.invalidate()
            permissionCheckTimer = nil
            print("権限状態の監視が停止されました")
        }
    }
    
    /// 権限状態の変更をチェック
    /// 権限状態が変更された場合にデリゲートに通知
    private func checkPermissionStatusChange() {
        let currentStatus = checkAccessibilityPermission()
        
        if currentStatus != lastPermissionStatus {
            print("権限状態が変更されました: \(lastPermissionStatus) -> \(currentStatus)")
            
            // デリゲートに通知
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.permissionStatusChanged(hasPermission: currentStatus)
            }
            
            lastPermissionStatus = currentStatus
        }
    }
    
    // MARK: - システム設定への誘導
    
    /// システム設定のプライバシーとセキュリティを開く
    /// アクセシビリティ権限の設定画面を表示
    func openPrivacySettings() {
        print("システム設定のプライバシーとセキュリティを開く中...")
        
        // システム設定のプライバシーとセキュリティを開く
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        
        NSWorkspace.shared.open(url)
        
        print("システム設定が開かれました")
    }
    
    /// アクセシビリティ設定を開く
    /// アクセシビリティ権限の設定画面を直接表示
    func openAccessibilitySettings() {
        print("アクセシビリティ設定を開く中...")
        
        // アクセシビリティ設定を開く
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        
        NSWorkspace.shared.open(url)
        
        print("アクセシビリティ設定が開かれました")
    }
    
    /// 権限要求ダイアログを表示
    /// ユーザーに権限の必要性を説明し、システム設定への誘導を行う
    func showPermissionRequestDialog() {
        print("権限要求ダイアログを表示中...")
        
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = """
        Window Restoreを使用するには、アクセシビリティ権限が必要です。
        
        1. システム環境設定を開きます
        2. 「プライバシーとセキュリティ」を選択
        3. 「アクセシビリティ」を選択
        4. Window Restoreにチェックを入れる
        
        設定後、アプリケーションを再起動してください。
        """
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
    
    /// 権限取得完了ダイアログを表示
    /// 権限が取得されたことをユーザーに通知
    func showPermissionGrantedDialog() {
        print("権限取得完了ダイアログを表示中...")
        
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が取得されました"
        alert.informativeText = "Window Restoreのすべての機能が使用できるようになりました。"
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        
        alert.runModal()
    }
    
    // MARK: - 通知
    
    /// 権限要求通知を表示
    /// システム通知で権限の必要性をユーザーに通知
    func showPermissionRequiredNotification() {
        print("権限要求通知を表示中...")
        
        let notification = NSUserNotification()
        notification.title = "アクセシビリティ権限が必要です"
        notification.informativeText = "Window Restoreを使用するには、システム環境設定でアクセシビリティ権限を有効にしてください。"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        // 通知アクションを追加
        notification.hasActionButton = true
        notification.actionButtonTitle = "設定を開く"
        notification.otherButtonTitle = "後で"
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    /// 権限取得完了通知を表示
    /// システム通知で権限取得をユーザーに通知
    func showPermissionGrantedNotification() {
        print("権限取得完了通知を表示中...")
        
        let notification = NSUserNotification()
        notification.title = "アクセシビリティ権限が取得されました"
        notification.informativeText = "Window Restoreのすべての機能が使用できるようになりました。"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - ヘルパーメソッド
    
    /// 権限状態を取得
    /// 戻り値: 現在の権限状態
    func getCurrentPermissionStatus() -> Bool {
        return lastPermissionStatus
    }
    
    /// 権限チェック間隔を設定
    /// 引数: interval - チェック間隔（秒）
    func setCheckInterval(_ interval: TimeInterval) {
        print("権限チェック間隔を設定中: \(interval)秒")
        
        // 現在のタイマーを停止
        stopPermissionMonitoring()
        
        // 新しい間隔でタイマーを再開
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPermissionStatusChange()
        }
        
        print("権限チェック間隔が設定されました")
    }
    
    /// 手動で権限状態を更新
    /// 即座に権限状態をチェックして更新
    func refreshPermissionStatus() {
        print("権限状態を手動更新中...")
        
        let currentStatus = checkAccessibilityPermission()
        
        if currentStatus != lastPermissionStatus {
            print("権限状態が変更されました: \(lastPermissionStatus) -> \(currentStatus)")
            
            // デリゲートに通知
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.permissionStatusChanged(hasPermission: currentStatus)
            }
            
            lastPermissionStatus = currentStatus
        }
        
        print("権限状態の手動更新が完了しました")
    }
}
