//! Permission checking functionality
//! 権限チェック機能
//! macOSのアクセシビリティ権限などをチェックする

use anyhow::Result;

#[link(name = "ApplicationServices", kind = "framework")]
extern "C" {
    fn AXIsProcessTrusted() -> u8; // macOS Boolean (UInt8)
}

/// macOS用権限チェッカー
/// アプリに必要な権限が付与されているかチェックする
pub struct PermissionChecker {
    // 権限チェックの内部状態
}

impl PermissionChecker {
    /// 新しいPermissionCheckerインスタンスを作成
    pub fn new() -> Result<Self> {
        Ok(Self {})
    }

    /// アクセシビリティ権限が付与されているかチェック
    /// 戻り値: 権限がある場合true
    pub fn check_accessibility_permission(&self) -> bool {
        log::debug!("Checking accessibility permissions");
        // AXIsProcessTrusted は現在のプロセスがアクセシビリティ権限を持つかを返す
        unsafe { AXIsProcessTrusted() != 0 }
    }

    /// アクセシビリティ権限をリクエスト
    /// システム環境設定のアクセシビリティセクションを開く
    pub fn request_accessibility_permission(&self) -> Result<()> {
        // TODO: アクセシビリティ権限のリクエストを実装
        // システム環境設定のアクセシビリティセクションを開く
        
        log::info!("Requesting accessibility permissions");
        
        // Placeholder implementation
        Ok(())
    }

    /// 画面収録権限が付与されているかチェック
    /// 一部のウィンドウ操作で必要になる場合がある
    pub fn check_screen_recording_permission(&self) -> bool {
        // TODO: 画面収録権限のチェックを実装
        // 一部のウィンドウ操作で必要になる場合がある
        
        log::debug!("Checking screen recording permissions");
        
        // Placeholder implementation
        true
    }

    /// 画面収録権限をリクエスト
    pub fn request_screen_recording_permission(&self) -> Result<()> {
        // TODO: 画面収録権限のリクエストを実装
        
        log::info!("Requesting screen recording permissions");
        
        // Placeholder implementation
        Ok(())
    }

    /// すべての必要な権限をチェック
    /// 戻り値: 権限の状態
    pub fn check_all_permissions(&self) -> PermissionStatus {
        let accessibility = self.check_accessibility_permission();
        let screen_recording = self.check_screen_recording_permission();
        
        PermissionStatus {
            accessibility,
            screen_recording,
            all_granted: accessibility && screen_recording,
        }
    }

    /// システム環境設定のプライバシーとセキュリティを開く
    pub fn open_privacy_settings(&self) -> Result<()> {
        log::info!("Opening Privacy & Security settings");
        
        // Open System Preferences to Privacy & Security
        let output = std::process::Command::new("open")
            .arg("x-apple.systempreferences:com.apple.preference.security?Privacy")
            .output()?;
        
        if !output.status.success() {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("Failed to open Privacy settings: {}", error_msg));
        }
        
        Ok(())
    }
}

/// 権限状態構造体
/// 各種権限の状態を保持
#[derive(Debug, Clone)]
pub struct PermissionStatus {
    pub accessibility: bool,     // アクセシビリティ権限
    pub screen_recording: bool,  // 画面収録権限
    pub all_granted: bool,       // すべての権限が付与されているか
}

/// アクセシビリティ権限をチェック（便利関数）
/// 戻り値: 権限がある場合true
pub fn check_accessibility_permission() -> bool {
    PermissionChecker::new()
        .map(|checker| checker.check_accessibility_permission())
        .unwrap_or(false)
}
