//! Layout management functionality
//! レイアウト管理機能
//! ウィンドウレイアウトの保存・読み込み・削除を行う

use anyhow::Result;
// use serde::{Deserialize, Serialize}; // 将来的に使用予定
use std::fs;
use std::path::PathBuf;
use chrono::Utc; // DateTimeは将来的に使用予定

use crate::window_scanner::WindowInfo;
use crate::window_restorer::Layout;

/// レイアウトマネージャー
/// レイアウトの保存と読み込みを管理する
pub struct LayoutManager {
    layouts_dir: PathBuf,  // レイアウトファイルを保存するディレクトリ
}

impl LayoutManager {
    /// 新しいLayoutManagerインスタンスを作成
    /// レイアウトディレクトリが存在しない場合は作成する
    pub fn new() -> Result<Self> {
        let layouts_dir = Self::get_layouts_dir()?;
        
        // Create layouts directory if it doesn't exist
        if !layouts_dir.exists() {
            fs::create_dir_all(&layouts_dir)?;
        }
        
        Ok(Self { layouts_dir })
    }

    /// レイアウトディレクトリのパスを取得
    /// ~/Library/Application Support/window_restore/layouts/
    fn get_layouts_dir() -> Result<PathBuf> {
        let mut path = dirs::data_dir()
            .ok_or_else(|| anyhow::anyhow!("Failed to get data directory"))?;
        path.push("window_restore");
        path.push("layouts");
        Ok(path)
    }

    /// レイアウトをディスクに保存
    /// 引数: name - レイアウト名、windows - ウィンドウ情報の配列
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

    /// レイアウトをディスクから読み込む
    /// 引数: name - 読み込むレイアウトの名前
    pub fn load_layout(&self, name: &str) -> Result<Layout> {
        let file_path = self.layouts_dir.join(format!("{}.json", name));
        let json = fs::read_to_string(file_path)?;
        let layout: Layout = serde_json::from_str(&json)?;
        Ok(layout)
    }

    /// 保存されたすべてのレイアウトをリスト
    /// 戻り値: レイアウト名の配列
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

    /// レイアウトを削除
    /// 引数: name - 削除するレイアウトの名前
    pub fn delete_layout(&self, name: &str) -> Result<()> {
        let file_path = self.layouts_dir.join(format!("{}.json", name));
        fs::remove_file(file_path)?;
        
        log::info!("Layout deleted: {}", name);
        Ok(())
    }

    /// レイアウトが存在するかチェック
    /// 引数: name - 確認するレイアウトの名前
    pub fn layout_exists(&self, name: &str) -> bool {
        let file_path = self.layouts_dir.join(format!("{}.json", name));
        file_path.exists()
    }
}
