//! Window Restore - macOS window position and size restoration utility
//!
//! This library provides functionality to save and restore window positions,
//! sizes, and display assignments on macOS.

pub mod window_scanner;
pub mod window_restorer;
pub mod layout_manager;
pub mod config;
pub mod app_launcher;
pub mod display_manager;
pub mod permission_checker;
pub mod notification;
pub mod ffi;

use anyhow::Result;
use thiserror::Error;

/// Error types for Window Restore
#[derive(Debug, Error)]
pub enum WindowRestoreError {
    #[error("Permission denied: {0}")]
    PermissionDenied(String),
    #[error("Application not found: {0}")]
    AppNotFound(String),
    #[error("Window not found: {0}")]
    WindowNotFound(String),
    #[error("Display not found: {0}")]
    DisplayNotFound(String),
    #[error("File I/O error: {0}")]
    FileIOError(#[from] std::io::Error),
    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),
}

/// Main entry point for the Window Restore library
pub struct WindowRestore {
    config: config::Config,
    layout_manager: layout_manager::LayoutManager,
    window_scanner: window_scanner::WindowScanner,
    window_restorer: window_restorer::WindowRestorer,
}

impl WindowRestore {
    /// Create a new WindowRestore instance
    pub fn new() -> Result<Self> {
        let config = config::Config::load()?;
        let layout_manager = layout_manager::LayoutManager::new()?;
        let window_scanner = window_scanner::WindowScanner::new()?;
        let window_restorer = window_restorer::WindowRestorer::new()?;

        Ok(Self {
            config,
            layout_manager,
            window_scanner,
            window_restorer,
        })
    }

    /// Save current window layout with given name
    pub fn save_layout(&self, name: &str) -> Result<()> {
        let windows = self.window_scanner.scan_windows()?;
        self.layout_manager.save_layout(name, &windows)?;
        Ok(())
    }

    /// Restore window layout with given name
    pub fn restore_layout(&self, name: &str) -> Result<()> {
        let layout = self.layout_manager.load_layout(name)?;
        self.window_restorer.restore_layout(&layout)?;
        Ok(())
    }

    /// Get list of saved layouts
    pub fn get_layout_list(&self) -> Result<Vec<String>> {
        self.layout_manager.list_layouts()
    }

    /// Delete layout with given name
    pub fn delete_layout(&self, name: &str) -> Result<()> {
        self.layout_manager.delete_layout(name)
    }

    /// Check if accessibility permissions are granted
    pub fn check_permissions(&self) -> bool {
        permission_checker::check_accessibility_permission()
    }
}

impl Default for WindowRestore {
    fn default() -> Self {
        Self::new().expect("Failed to create WindowRestore instance")
    }
}
