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
        // 優先: 環境変数で指定
        if let Ok(base) = std::env::var("WINDOW_RESTORE_DATA_DIR") {
            let mut path = PathBuf::from(base);
            path.push("layouts");
            return Ok(path);
        }
        // 通常: ユーザーデータディレクトリ
        if let Some(mut path) = dirs::data_dir() {
            path.push("window_restore");
            path.push("layouts");
            return Ok(path);
        }
        // フォールバック: プロジェクトのtarget配下（テストやサンドボックス向け）
        let mut path = std::env::current_dir()?;
        path.push("target");
        path.push("window_restore");
        path.push("layouts");
        Ok(path)
    }

    /// レイアウト名のバリデーション
    /// - 空文字不可
    /// - ファイル名に使えない文字は不可（/、\、:、*、?、"、<、>、|）
    fn validate_layout_name(name: &str) -> Result<()> {
        if name.trim().is_empty() {
            return Err(anyhow::anyhow!("Layout name must not be empty"));
        }
        let invalid_chars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
        if name.chars().any(|c| invalid_chars.contains(&c)) {
            return Err(anyhow::anyhow!("Layout name contains invalid characters"));
        }
        Ok(())
    }

    /// レイアウト全体のバリデーション
    /// - layout_name検証
    /// - ウィンドウ配列の健全性チェック
    pub fn validate_layout(&self, layout: &Layout) -> Result<()> {
        Self::validate_layout_name(&layout.layout_name)?;
        for w in &layout.windows {
            if w.app_name.trim().is_empty() {
                return Err(anyhow::anyhow!("Window app_name must not be empty"));
            }
            if w.title.trim().is_empty() {
                return Err(anyhow::anyhow!("Window title must not be empty"));
            }
            if !w.frame.width.is_finite() || !w.frame.height.is_finite() || w.frame.width < 0.0 || w.frame.height < 0.0 {
                return Err(anyhow::anyhow!("Window frame has invalid size"));
            }
            if !w.frame.x.is_finite() || !w.frame.y.is_finite() {
                return Err(anyhow::anyhow!("Window frame has invalid position"));
            }
            if w.display_uuid.trim().is_empty() {
                return Err(anyhow::anyhow!("Window display_uuid must not be empty"));
            }
        }
        Ok(())
    }

    /// レイアウトをディスクに保存
    /// 引数: name - レイアウト名、windows - ウィンドウ情報の配列
    pub fn save_layout(&self, name: &str, windows: &[WindowInfo]) -> Result<()> {
        // 名前バリデーション
        Self::validate_layout_name(name)?;

        let file_path = self.layouts_dir.join(format!("{}.json", name));

        // 既存レイアウトがある場合はcreated_atを保持
        let created_at = if file_path.exists() {
            if let Ok(existing_json) = fs::read_to_string(&file_path) {
                if let Ok(existing_layout) = serde_json::from_str::<Layout>(&existing_json) {
                    existing_layout.created_at
                } else { Utc::now().to_rfc3339() }
            } else { Utc::now().to_rfc3339() }
        } else {
            Utc::now().to_rfc3339()
        };

        let layout = Layout {
            layout_name: name.to_string(),
            created_at,
            updated_at: Utc::now().to_rfc3339(),
            windows: windows.to_vec(),
        };

        // レイアウトのバリデーション
        self.validate_layout(&layout)?;

        let json = serde_json::to_string_pretty(&layout)?;
        fs::write(file_path, json)?;
        
        log::info!("Layout saved: {}", name);
        Ok(())
    }

    /// レイアウトをディスクから読み込む
    /// 引数: name - 読み込むレイアウトの名前
    pub fn load_layout(&self, name: &str) -> Result<Layout> {
        // 名前バリデーション
        Self::validate_layout_name(name)?;

        let file_path = self.layouts_dir.join(format!("{}.json", name));
        let json = fs::read_to_string(file_path)?;
        let layout: Layout = serde_json::from_str(&json)?;
        // 読み込んだレイアウトのバリデーション
        self.validate_layout(&layout)?;
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
        // 名前バリデーション
        Self::validate_layout_name(name)?;

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
