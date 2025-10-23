//! Configuration management functionality
//! アプリケーション設定の管理機能

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// アプリケーション設定
/// JSON形式でディスクに保存される
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub auto_restore: bool,                  // 自動復元を有効にするか
    pub display_change_detection: bool,      // ディスプレイ変更を検知するか
    pub exclude_apps: Vec<String>,          // 除外するアプリのバンドルIDリスト
    pub minimize_hidden_windows: bool,       // 最小化・非表示ウィンドウを除外するか
    pub restore_delay_ms: u64,              // 復元時の遅延（ミリ秒）
    pub max_retry_attempts: u32,            // 最大再試行回数
    pub scan_interval_ms: u64,              // スキャン間隔（ミリ秒）
    pub max_memory_usage_mb: u64,           // 最大メモリ使用量（MB）
}

impl Default for Config {
    fn default() -> Self {
        Self {
            auto_restore: false,
            display_change_detection: true,
            exclude_apps: vec!["com.apple.finder".to_string()],
            minimize_hidden_windows: true,
            restore_delay_ms: 1000,
            max_retry_attempts: 3,
            scan_interval_ms: 5000,
            max_memory_usage_mb: 50,
        }
    }
}

impl Config {
    /// ディスクから設定を読み込む
    /// ファイルが存在しない場合はデフォルト設定を作成して保存する
    pub fn load() -> Result<Self> {
        let config_path = Self::get_config_path()?;
        
        if config_path.exists() {
            let json = fs::read_to_string(config_path)?;
            let config: Config = serde_json::from_str(&json)?;
            Ok(config)
        } else {
            let config = Config::default();
            config.save()?;
            Ok(config)
        }
    }

    /// 設定をディスクに保存
    /// JSON形式で保存される
    pub fn save(&self) -> Result<()> {
        let config_path = Self::get_config_path()?;
        
        // Create config directory if it doesn't exist
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }
        
        let json = serde_json::to_string_pretty(self)?;
        fs::write(config_path, json)?;
        
        log::info!("Configuration saved");
        Ok(())
    }

    /// 設定ファイルのパスを取得
    /// ~/Library/Application Support/window_restore/config.json
    fn get_config_path() -> Result<PathBuf> {
        // 優先: 環境変数で指定
        if let Ok(base) = std::env::var("WINDOW_RESTORE_DATA_DIR") {
            let mut path = PathBuf::from(base);
            path.push("config.json");
            return Ok(path);
        }
        // 通常: ユーザーデータディレクトリ
        if let Some(mut path) = dirs::data_dir() {
            path.push("window_restore");
            path.push("config.json");
            return Ok(path);
        }
        // フォールバック: プロジェクトのtarget配下（テスト/サンドボックス向け）
        let mut path = std::env::current_dir()?;
        path.push("target");
        path.push("window_restore");
        path.push("config.json");
        Ok(path)
    }

    /// アプリが除外対象かチェック
    /// 引数: bundle_id - 確認するアプリのバンドルID
    pub fn is_app_excluded(&self, bundle_id: &str) -> bool {
        self.exclude_apps.contains(&bundle_id.to_string())
    }

    /// アプリを除外リストに追加
    /// 引数: bundle_id - 除外するアプリのバンドルID
    pub fn exclude_app(&mut self, bundle_id: &str) {
        if !self.exclude_apps.contains(&bundle_id.to_string()) {
            self.exclude_apps.push(bundle_id.to_string());
        }
    }

    /// アプリを除外リストから削除
    /// 引数: bundle_id - 除外を解除するアプリのバンドルID
    pub fn include_app(&mut self, bundle_id: &str) {
        self.exclude_apps.retain(|id| id != bundle_id);
    }
}
