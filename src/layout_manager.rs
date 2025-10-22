//! Layout management functionality

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use chrono::{DateTime, Utc};

use crate::window_scanner::WindowInfo;
use crate::window_restorer::Layout;

/// Layout manager for saving and loading layouts
pub struct LayoutManager {
    layouts_dir: PathBuf,
}

impl LayoutManager {
    /// Create a new LayoutManager instance
    pub fn new() -> Result<Self> {
        let layouts_dir = Self::get_layouts_dir()?;
        
        // Create layouts directory if it doesn't exist
        if !layouts_dir.exists() {
            fs::create_dir_all(&layouts_dir)?;
        }
        
        Ok(Self { layouts_dir })
    }

    /// Get the layouts directory path
    fn get_layouts_dir() -> Result<PathBuf> {
        let mut path = dirs::data_dir()
            .ok_or_else(|| anyhow::anyhow!("Failed to get data directory"))?;
        path.push("window_restore");
        path.push("layouts");
        Ok(path)
    }

    /// Save a layout to disk
    pub fn save_layout(&self, name: &str, windows: &[WindowInfo]) -> Result<()> {
        let now = Utc::now();
        let layout = Layout {
            layout_name: name.to_string(),
            created_at: now.to_rfc3339(),
            updated_at: now.to_rfc3339(),
            windows: windows.to_vec(),
        };

        let file_path = self.layouts_dir.join(format!("{}.json", name));
        let json = serde_json::to_string_pretty(&layout)?;
        fs::write(file_path, json)?;
        
        log::info!("Layout saved: {}", name);
        Ok(())
    }

    /// Load a layout from disk
    pub fn load_layout(&self, name: &str) -> Result<Layout> {
        let file_path = self.layouts_dir.join(format!("{}.json", name));
        let json = fs::read_to_string(file_path)?;
        let layout: Layout = serde_json::from_str(&json)?;
        Ok(layout)
    }

    /// List all saved layouts
    pub fn list_layouts(&self) -> Result<Vec<String>> {
        let mut layouts = Vec::new();
        
        if self.layouts_dir.exists() {
            for entry in fs::read_dir(&self.layouts_dir)? {
                let entry = entry?;
                let path = entry.path();
                
                if path.extension().and_then(|s| s.to_str()) == Some("json") {
                    if let Some(name) = path.file_stem().and_then(|s| s.to_str()) {
                        layouts.push(name.to_string());
                    }
                }
            }
        }
        
        layouts.sort();
        Ok(layouts)
    }

    /// Delete a layout
    pub fn delete_layout(&self, name: &str) -> Result<()> {
        let file_path = self.layouts_dir.join(format!("{}.json", name));
        fs::remove_file(file_path)?;
        
        log::info!("Layout deleted: {}", name);
        Ok(())
    }

    /// Check if a layout exists
    pub fn layout_exists(&self, name: &str) -> bool {
        let file_path = self.layouts_dir.join(format!("{}.json", name));
        file_path.exists()
    }
}
