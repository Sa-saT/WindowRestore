//! Configuration management functionality

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// Application configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub auto_restore: bool,
    pub display_change_detection: bool,
    pub exclude_apps: Vec<String>,
    pub minimize_hidden_windows: bool,
    pub restore_delay_ms: u64,
    pub max_retry_attempts: u32,
    pub scan_interval_ms: u64,
    pub max_memory_usage_mb: u64,
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
    /// Load configuration from disk
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

    /// Save configuration to disk
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

    /// Get the configuration file path
    fn get_config_path() -> Result<PathBuf> {
        let mut path = dirs::data_dir()
            .ok_or_else(|| anyhow::anyhow!("Failed to get data directory"))?;
        path.push("window_restore");
        path.push("config.json");
        Ok(path)
    }

    /// Check if an app should be excluded
    pub fn is_app_excluded(&self, bundle_id: &str) -> bool {
        self.exclude_apps.contains(&bundle_id.to_string())
    }

    /// Add an app to the exclusion list
    pub fn exclude_app(&mut self, bundle_id: &str) {
        if !self.exclude_apps.contains(&bundle_id.to_string()) {
            self.exclude_apps.push(bundle_id.to_string());
        }
    }

    /// Remove an app from the exclusion list
    pub fn include_app(&mut self, bundle_id: &str) {
        self.exclude_apps.retain(|id| id != bundle_id);
    }
}
