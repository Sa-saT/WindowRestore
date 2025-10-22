//! Application launcher functionality
//! アプリケーション起動機能
//! macOSのアプリケーションを起動・管理する

use anyhow::Result;
use std::process::Command;

/// macOS用アプリケーションランチャー
/// アプリケーションの起動と実行状態の確認を行う
pub struct AppLauncher {
    // アプリ起動の内部状態
}

impl AppLauncher {
    /// 新しいAppLauncherインスタンスを作成
    pub fn new() -> Result<Self> {
        Ok(Self {})
    }

    /// バンドルIDを指定してアプリケーションを起動
    /// 引数: bundle_id - 起動するアプリのバンドルID（例: com.apple.safari）
    pub fn launch_app(&self, bundle_id: &str) -> Result<()> {
        log::info!("Launching application: {}", bundle_id);
        
        let output = Command::new("open")
            .arg("-b")
            .arg(bundle_id)
            .output()?;
        
        if !output.status.success() {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("Failed to launch app {}: {}", bundle_id, error_msg));
        }
        
        log::info!("Successfully launched application: {}", bundle_id);
        Ok(())
    }

    /// アプリケーションが実行中かチェック
    /// 引数: bundle_id - 確認するアプリのバンドルID
    pub fn is_app_running(&self, bundle_id: &str) -> bool {
        let output = Command::new("pgrep")
            .arg("-f")
            .arg(bundle_id)
            .output();
        
        match output {
            Ok(result) => result.status.success(),
            Err(_) => false,
        }
    }

    /// 実行中のアプリケーション一覧を取得
    /// 戻り値: 実行中アプリの名前リスト
    pub fn get_running_apps(&self) -> Result<Vec<String>> {
        let output = Command::new("ps")
            .arg("-ax")
            .arg("-o")
            .arg("comm")
            .output()?;
        
        let stdout = String::from_utf8(output.stdout)?;
        let apps: Vec<String> = stdout
            .lines()
            .map(|line| line.trim().to_string())
            .filter(|line| !line.is_empty())
            .collect();
        
        Ok(apps)
    }

    /// アプリケーションの起動を待機
    /// 引数: bundle_id - 待機するアプリのバンドルID, timeout_ms - タイムアウト（ミリ秒）
    pub fn wait_for_app(&self, bundle_id: &str, timeout_ms: u64) -> Result<()> {
        let start_time = std::time::Instant::now();
        let timeout = std::time::Duration::from_millis(timeout_ms);
        
        while start_time.elapsed() < timeout {
            if self.is_app_running(bundle_id) {
                return Ok(());
            }
            
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        
        Err(anyhow::anyhow!("Timeout waiting for app to start: {}", bundle_id))
    }
}
