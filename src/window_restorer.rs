//! Window restoration functionality for macOS
//! macOS用ウィンドウ復元機能
//! 保存されたレイアウトに基づいてウィンドウを復元する

use anyhow::{Result, anyhow};
use serde::{Deserialize, Serialize};
// use std::collections::HashMap; // 将来的に使用予定
use std::process::Command; // AppleScript実行用（暫定実装）
use std::thread;
use std::time::Duration;

use crate::window_scanner::{WindowInfo, WindowLevel};
use crate::app_launcher::AppLauncher;
use crate::display_manager::DisplayManager;
use crate::permission_checker::PermissionChecker;

/// レイアウト構造体
/// 保存・復元に使用するレイアウト情報
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Layout {
    pub layout_name: String,  // レイアウト名
    pub created_at: String,   // 作成日時
    pub updated_at: String,   // 更新日時
    pub windows: Vec<WindowInfo>, // ウィンドウ情報のリスト
}

/// macOS用ウィンドウリストアラー
/// ウィンドウの位置・サイズを復元する
pub struct WindowRestorer {
    app_launcher: AppLauncher,        // アプリ起動支援
    display_manager: DisplayManager,   // ディスプレイ管理
    permission_checker: PermissionChecker, // 権限チェック
    restore_delay_ms: u64,            // 復元間隔（ミリ秒）
    _max_retry_attempts: u32,         // 最大リトライ回数
}

impl WindowRestorer {
    /// 新しいWindowRestorerインスタンスを作成
    pub fn new() -> Result<Self> {
        let app_launcher = AppLauncher::new()?;
        let display_manager = DisplayManager::new()?;
        let permission_checker = PermissionChecker::new()?;
        
        Ok(Self {
            app_launcher,
            display_manager,
            permission_checker,
            restore_delay_ms: 1000,  // デフォルト1秒間隔
            _max_retry_attempts: 3,   // デフォルト3回リトライ
        })
    }

    /// レイアウトを復元
    /// 引数: layout - 復元するレイアウト情報
    pub fn restore_layout(&mut self, layout: &Layout) -> Result<()> {
        log::info!("Restoring layout: {}", layout.layout_name);
        
        // 権限チェック
        if !self.permission_checker.check_accessibility_permission() {
            return Err(anyhow::anyhow!("Accessibility permission required for window restoration"));
        }
        
        // ディスプレイ情報を更新
        self.display_manager.refresh_displays()?;
        
        // アプリケーションを起動（必要に応じて）
        let mut launched_apps = Vec::new();
        for window in &layout.windows {
            if !self.app_launcher.is_app_running(&window.bundle_id) {
                log::info!("Launching application: {}", window.app_name);
                self.app_launcher.launch_app(&window.bundle_id)?;
                launched_apps.push(window.bundle_id.clone());
            }
        }
        
        // アプリケーションの起動を待機
        for bundle_id in &launched_apps {
            self.app_launcher.wait_for_app(bundle_id, 10000)?; // 10秒 = 10000ミリ秒
        }
        
        // 復元間隔を待機
        thread::sleep(Duration::from_millis(self.restore_delay_ms));
        
        // ウィンドウを復元
        let mut success_count = 0;
        let mut failed_windows = Vec::new();
        
        for window in &layout.windows {
            match self.restore_window(window) {
                Ok(_) => {
                    success_count += 1;
                    log::debug!("Successfully restored window: {} - {}", window.app_name, window.title);
                }
                Err(e) => {
                    log::warn!("Failed to restore window: {} - {}: {}", window.app_name, window.title, e);
                    failed_windows.push(window.clone());
                }
            }
            
            // ウィンドウ間の復元間隔
            thread::sleep(Duration::from_millis(200));
        }
        
        log::info!("Layout restoration completed: {}/{} windows restored", 
                  success_count, layout.windows.len());
        
        if !failed_windows.is_empty() {
            log::warn!("Failed to restore {} windows", failed_windows.len());
        }
        
        Ok(())
    }

    /// 単一のウィンドウを復元（リトライ機能付き）
    /// 引数: window - 復元するウィンドウ情報
    fn restore_window(&self, window: &WindowInfo) -> Result<()> {
        // 関連ディスプレイ情報を取得
        let _target_display = match self.display_manager.get_display_by_uuid(&window.display_uuid) {
            Some(display) => display,
            None => {
                log::warn!("Target display not found for window: {}, falling back to main display", window.title);
                // フォールバック: メインディスプレイを使用
                self.display_manager.get_main_display()
                    .ok_or_else(|| anyhow!("No displays available"))?
            }
        };

        // 座標変換（エラー時はオリジナル座標を使用）
        let (display_uuid, new_x, new_y) = self.display_manager.screen_to_display_coords(
            window.frame.x,
            window.frame.y
        ).unwrap_or_else(|| {
            log::warn!("Failed to convert coordinates, using original: x={}, y={}", window.frame.x, window.frame.y);
            (window.display_uuid.clone(), window.frame.x, window.frame.y)
        });

        if display_uuid != window.display_uuid {
            log::warn!("Display UUID mismatch for window: {}", window.title);
        }

        // リトライロジック付きでウィンドウを移動
        let max_retries = 3;
        let mut last_error = None;
        
        for attempt in 1..=max_retries {
            match self.try_restore_window_position(window, new_x, new_y) {
                Ok(_) => {
                    log::info!("Successfully restored window on attempt {}: {}", attempt, window.title);
                    return Ok(());
                }
                Err(e) => {
                    log::warn!("Attempt {}/{} failed for window '{}': {}", attempt, max_retries, window.title, e);
                    last_error = Some(e);
                    if attempt < max_retries {
                        thread::sleep(Duration::from_millis(500));
                    }
                }
            }
        }

        Err(last_error.unwrap_or_else(|| anyhow!("Failed to restore window after {} attempts", max_retries)))
    }
    
    /// ウィンドウ位置の復元を試行（単一試行）
    /// 引数: window - 復元するウィンドウ、x, y - 目標座標
    fn try_restore_window_position(&self, window: &WindowInfo, x: f64, y: f64) -> Result<()> {
        // osascriptによるウィンドウの移動（暫定）
        let script = format!(
            r#"tell application "System Events"
  tell process "{}"
    try
      set position of first window to {{{}, {}}}
      return "OK"
    on error errMsg
      return errMsg
    end try
  end tell
end tell"#,
            window.app_name.replace('"', "\\\""), x as i64, y as i64
        );

        let output = Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|e| anyhow!("Failed to execute osascript: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("AppleScript execution failed: {}", stderr));
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        if !stdout.trim().ends_with("OK") {
            return Err(anyhow!("AppleScript returned error: {}", stdout.trim()));
        }

        Ok(())
    }
    
    /// ウィンドウを検索して復元
    /// 引数: window - 復元するウィンドウ情報
    fn find_and_restore_window(&self, window: &WindowInfo) -> Result<()> {
        // 現在のウィンドウ一覧を取得
        let current_windows = self.get_current_windows()?;
        
        // 対象ウィンドウを検索
        let target_window = current_windows.iter()
            .find(|w| w.app_name == window.app_name && w.title == window.title)
            .ok_or_else(|| anyhow::anyhow!("Window not found: {} - {}", window.app_name, window.title))?;
        
        // ディスプレイに基づく座標補正（将来：window.display_uuidでの判定）
        let (x, y) = if let Some((screen_x, screen_y)) = self.display_manager.display_to_screen_coords("main", window.frame.x, window.frame.y) {
            (screen_x, screen_y)
        } else {
            (window.frame.x, window.frame.y)
        };
        let corrected = crate::window_scanner::WindowFrame { x, y, width: window.frame.width, height: window.frame.height };

        // ウィンドウを移動
        self.move_window_to_position(target_window, &corrected)?;
        
        // ウィンドウレベルを設定
        self.set_window_level(target_window, window.window_level)?;
        
        // 最小化・非表示状態を復元
        if window.is_minimized {
            self.minimize_window(target_window)?;
        } else if window.is_hidden {
            self.hide_window(target_window)?;
        } else {
            self.show_window(target_window)?;
        }
        
        Ok(())
    }

    /// 現在のウィンドウ一覧を取得
    /// 戻り値: 現在表示中のウィンドウ情報のリスト
    fn get_current_windows(&self) -> Result<Vec<WindowInfo>> {
        // window_scannerを使用して現在のウィンドウ一覧を取得
        let scanner = crate::window_scanner::WindowScanner::new()?;
        scanner.scan_windows()
    }
    
    /// ウィンドウを指定された位置に移動
    /// 引数: window - 移動するウィンドウ、frame - 目標位置とサイズ
    fn move_window_to_position(&self, window: &WindowInfo, frame: &crate::window_scanner::WindowFrame) -> Result<()> {
        log::debug!("Moving window '{}' to: x={}, y={}, w={}, h={}", window.title, frame.x, frame.y, frame.width, frame.height);

        // AppleScriptを使って暫定的にウィンドウの位置・サイズを変更（AX権限が必要）
        // 注意: 同名ウィンドウが複数ある場合の識別は今後拡張
        let script = format!(
            r#"tell application "System Events"
  tell process "{}"
    try
      tell window 1
        set position to {{{}, {}}}
        set size to {{{}, {}}}
      end tell
      return "OK"
    on error errMsg
      return errMsg
    end try
  end tell
end tell"#,
            window.app_name.replace('"', "\\\""),
            frame.x as i64, frame.y as i64, frame.width as i64, frame.height as i64
        );

        let output = Command::new("osascript").arg("-e").arg(script).output()?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("Failed to move window via AppleScript: {}", stderr));
        }
        let stdout = String::from_utf8_lossy(&output.stdout);
        if !stdout.trim().ends_with("OK") {
            return Err(anyhow::anyhow!("AppleScript error: {}", stdout.trim()));
        }
        Ok(())
    }
    
    /// ウィンドウレベルを設定
    /// 引数: window - 対象ウィンドウ、level - 設定するレベル
    fn set_window_level(&self, _window: &WindowInfo, level: WindowLevel) -> Result<()> {
        log::debug!("Setting window level to: {:?}", level);
        
        // TODO: ウィンドウレベルを設定
        // Core Graphics APIを使用してウィンドウレベルを変更
        
        Ok(())
    }
    
    /// ウィンドウを最小化
    /// 引数: window - 最小化するウィンドウ
    fn minimize_window(&self, window: &WindowInfo) -> Result<()> {
        log::debug!("Minimizing window: {} - {}", window.app_name, window.title);
        let script = format!(
            r#"tell application "System Events"
  tell process "{}"
    try
      set miniaturized of window 1 to true
      return "OK"
    on error errMsg
      return errMsg
    end try
  end tell
end tell"#,
            window.app_name.replace('"', "\\\"")
        );
        let output = Command::new("osascript").arg("-e").arg(script).output()?;
        if !output.status.success() { return Err(anyhow::anyhow!("Failed to minimize window")); }
        Ok(())
    }
    
    /// ウィンドウを非表示
    /// 引数: window - 非表示にするウィンドウ
    fn hide_window(&self, window: &WindowInfo) -> Result<()> {
        log::debug!("Hiding window: {} - {}", window.app_name, window.title);
        let script = format!(
            r#"tell application "System Events"
  tell process "{}"
    try
      set visible to false
      return "OK"
    on error errMsg
      return errMsg
    end try
  end tell
end tell"#,
            window.app_name.replace('"', "\\\"")
        );
        let output = Command::new("osascript").arg("-e").arg(script).output()?;
        if !output.status.success() { return Err(anyhow::anyhow!("Failed to hide window")); }
        Ok(())
    }
    
    /// ウィンドウを表示
    /// 引数: window - 表示するウィンドウ
    fn show_window(&self, window: &WindowInfo) -> Result<()> {
        log::debug!("Showing window: {} - {}", window.app_name, window.title);
        let script = format!(
            r#"tell application "System Events"
  tell process "{}"
    try
      set visible to true
      return "OK"
    on error errMsg
      return errMsg
    end try
  end tell
end tell"#,
            window.app_name.replace('"', "\\\"")
        );
        let output = Command::new("osascript").arg("-e").arg(script).output()?;
        if !output.status.success() { return Err(anyhow::anyhow!("Failed to show window")); }
        Ok(())
    }

    /// アプリケーション起動を待機
    /// 引数: bundle_id - アプリのバンドルID
    fn wait_for_app(&self, bundle_id: &str, timeout_ms: u64) -> Result<()> {
        log::info!("Waiting for application to launch: {}", bundle_id);

        let mut elapsed = 0;
        let interval = 500; // チェック間隔500ミリ秒

        while elapsed < timeout_ms {
            if self.app_launcher.is_app_running(bundle_id) {
                log::info!("Application is running: {}", bundle_id);
                return Ok(());
            }
            thread::sleep(Duration::from_millis(interval));
            elapsed += interval;
        }

        Err(anyhow!("Timeout waiting for application to launch: {}", bundle_id))
    }
}
