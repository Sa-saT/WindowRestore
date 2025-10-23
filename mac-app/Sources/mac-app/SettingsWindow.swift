//! SettingsWindow.swift - アプリケーション設定ウィンドウ
//! アプリケーション設定ウィンドウ
//! 各種設定項目の表示と変更を管理

import Cocoa
import Foundation

/// 設定ウィンドウのデリゲートプロトコル
/// 設定変更のイベントを処理
protocol SettingsWindowDelegate: AnyObject {
    /// 設定が変更された時に呼ばれる
    func settingsDidChange()
}

/// アプリケーション設定ウィンドウ
/// 各種設定項目の表示と変更を管理
class SettingsWindow: NSWindow {
    
    // MARK: - プロパティ
    
    /// デリゲート
    weak var settingsDelegate: SettingsWindowDelegate?
    
    /// 設定ウィンドウのコントローラー参照（名称衝突回避）
    private var settingsWindowControllerRef: NSWindowController?
    
    // UI要素
    /// 自動復元チェックボックス
    private var autoRestoreCheckbox: NSButton!
    
    /// ディスプレイ変化検知チェックボックス
    private var detectDisplayChangesCheckbox: NSButton!
    
    /// 復元遅延スライダー
    private var restoreDelaySlider: NSSlider!
    
    /// 復元遅延ラベル
    private var restoreDelayLabel: NSTextField!
    
    /// 除外アプリケーションリスト
    private var excludedAppsTextView: NSTextView!
    
    // MARK: - 初期化
    
    /// イニシャライザ
    init() {
        // ウィンドウのサイズと位置を設定
        let contentRect = NSRect(x: 0, y: 0, width: 500, height: 400)
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // ウィンドウの設定
        self.title = "Window Restore - 設定"
        self.center()
        self.isReleasedWhenClosed = false
        
        // UIを構築
        setupUI()
    }
    
    // MARK: - UI構築
    
    /// UIの構築
    /// 設定画面のUI要素を配置
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // コンテンツビューの背景色を設定
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // タイトルラベル
        let titleLabel = NSTextField(labelWithString: "アプリケーション設定")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 350, width: 460, height: 30)
        contentView.addSubview(titleLabel)
        
        // 自動復元チェックボックス
        autoRestoreCheckbox = NSButton(checkboxWithTitle: "ログイン時に自動的にレイアウトを復元", target: self, action: #selector(autoRestoreChanged))
        autoRestoreCheckbox.frame = NSRect(x: 20, y: 310, width: 460, height: 24)
        autoRestoreCheckbox.state = .off // デフォルト: オフ
        contentView.addSubview(autoRestoreCheckbox)
        
        // ディスプレイ変化検知チェックボックス
        detectDisplayChangesCheckbox = NSButton(checkboxWithTitle: "ディスプレイ構成の変化を検知", target: self, action: #selector(detectDisplayChangesChanged))
        detectDisplayChangesCheckbox.frame = NSRect(x: 20, y: 280, width: 460, height: 24)
        detectDisplayChangesCheckbox.state = .on // デフォルト: オン
        contentView.addSubview(detectDisplayChangesCheckbox)
        
        // 復元遅延設定
        let delayLabel = NSTextField(labelWithString: "復元間隔（ミリ秒）:")
        delayLabel.frame = NSRect(x: 20, y: 240, width: 150, height: 24)
        contentView.addSubview(delayLabel)
        
        restoreDelaySlider = NSSlider(frame: NSRect(x: 180, y: 240, width: 200, height: 24))
        restoreDelaySlider.minValue = 200
        restoreDelaySlider.maxValue = 5000
        restoreDelaySlider.doubleValue = 1000 // デフォルト: 1000ms
        restoreDelaySlider.target = self
        restoreDelaySlider.action = #selector(restoreDelayChanged)
        contentView.addSubview(restoreDelaySlider)
        
        restoreDelayLabel = NSTextField(labelWithString: "1000 ms")
        restoreDelayLabel.frame = NSRect(x: 390, y: 240, width: 90, height: 24)
        restoreDelayLabel.alignment = .right
        contentView.addSubview(restoreDelayLabel)
        
        // 除外アプリケーション設定
        let excludedAppsLabel = NSTextField(labelWithString: "除外するアプリケーション（1行に1つ）:")
        excludedAppsLabel.frame = NSRect(x: 20, y: 200, width: 460, height: 24)
        contentView.addSubview(excludedAppsLabel)
        
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 460, height: 110))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        excludedAppsTextView = NSTextView(frame: scrollView.bounds)
        excludedAppsTextView.isEditable = true
        excludedAppsTextView.isRichText = false
        excludedAppsTextView.font = NSFont.systemFont(ofSize: 12)
        excludedAppsTextView.string = "Finder\nDock"
        
        scrollView.documentView = excludedAppsTextView
        contentView.addSubview(scrollView)
        
        // 保存ボタン
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: 300, y: 20, width: 80, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enterキーでも保存可能
        contentView.addSubview(saveButton)
        
        // キャンセルボタン
        let cancelButton = NSButton(title: "キャンセル", target: self, action: #selector(closeWindow))
        cancelButton.frame = NSRect(x: 390, y: 20, width: 90, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escキーでも閉じられる
        contentView.addSubview(cancelButton)
        
        // 設定を読み込み
        loadSettings()
    }
    
    // MARK: - 設定の読み込みと保存
    
    /// 設定を読み込み
    /// UserDefaultsから設定を読み込んでUIに反映
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // 自動復元設定
        let autoRestore = defaults.bool(forKey: "autoRestore")
        autoRestoreCheckbox.state = autoRestore ? .on : .off
        
        // ディスプレイ変化検知設定
        let detectDisplayChanges = defaults.bool(forKey: "detectDisplayChanges")
        detectDisplayChangesCheckbox.state = detectDisplayChanges ? .on : .off
        
        // 復元遅延設定
        let restoreDelay = defaults.integer(forKey: "restoreDelay")
        if restoreDelay > 0 {
            restoreDelaySlider.doubleValue = Double(restoreDelay)
            restoreDelayLabel.stringValue = "\(restoreDelay) ms"
        }
        
        // 除外アプリケーション設定
        if let excludedApps = defaults.array(forKey: "excludedApps") as? [String] {
            excludedAppsTextView.string = excludedApps.joined(separator: "\n")
        }
    }
    
    /// 設定を保存
    /// UIの状態をUserDefaultsに保存
    @objc private func saveSettings() {
        let defaults = UserDefaults.standard
        
        // 自動復元設定
        defaults.set(autoRestoreCheckbox.state == .on, forKey: "autoRestore")
        
        // ディスプレイ変化検知設定
        defaults.set(detectDisplayChangesCheckbox.state == .on, forKey: "detectDisplayChanges")
        
        // 復元遅延設定
        defaults.set(Int(restoreDelaySlider.doubleValue), forKey: "restoreDelay")
        
        // 除外アプリケーション設定
        let excludedAppsText = excludedAppsTextView.string
        let excludedApps = excludedAppsText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        defaults.set(excludedApps, forKey: "excludedApps")
        
        // 保存を実行
        defaults.synchronize()
        
        // デリゲートに通知
        settingsDelegate?.settingsDidChange()
        
        // ウィンドウを閉じる
        closeWindow()
        
        // 保存成功の通知を表示
        showSaveSuccessNotification()
    }
    
    // MARK: - アクション
    
    /// 自動復元設定が変更された
    @objc private func autoRestoreChanged() {
        print("自動復元設定が変更されました: \(autoRestoreCheckbox.state == .on)")
    }
    
    /// ディスプレイ変化検知設定が変更された
    @objc private func detectDisplayChangesChanged() {
        print("ディスプレイ変化検知設定が変更されました: \(detectDisplayChangesCheckbox.state == .on)")
    }
    
    /// 復元遅延が変更された
    @objc private func restoreDelayChanged() {
        let value = Int(restoreDelaySlider.doubleValue)
        restoreDelayLabel.stringValue = "\(value) ms"
    }
    
    /// ウィンドウを閉じる
    @objc private func closeWindow() {
        self.orderOut(nil)
    }
    
    /// 保存成功通知を表示
    private func showSaveSuccessNotification() {
        let alert = NSAlert()
        alert.messageText = "設定を保存しました"
        alert.informativeText = "設定が正常に保存されました。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - 公開メソッド
    
    /// 設定ウィンドウを表示
    /// 設定ウィンドウを前面に表示
    func show() {
        // 設定を再読み込み
        loadSettings()
        
        // ウィンドウを表示
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

