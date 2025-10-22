//! Display management functionality
//! ディスプレイ管理機能
//! 接続されているディスプレイの情報を管理する

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// ディスプレイ情報構造体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayInfo {
    pub uuid: String,         // ディスプレイの一意識別子
    pub name: String,         // ディスプレイ名
    pub frame: DisplayFrame,  // ディスプレイのフレーム
    pub is_main: bool,        // メインディスプレイかどうか
    pub scale_factor: f64,    // スケールファクター（Retina対応）
}

/// ディスプレイフレーム構造体
/// ディスプレイの位置とサイズを表す
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayFrame {
    pub x: f64,      // X座標
    pub y: f64,      // Y座標
    pub width: f64,  // 幅
    pub height: f64, // 高さ
}

/// macOS用ディスプレイマネージャー
/// 接続されているディスプレイの情報を管理
pub struct DisplayManager {
    displays: HashMap<String, DisplayInfo>,  // UUIDをキーとするディスプレイ情報
}

impl DisplayManager {
    /// 新しいDisplayManagerインスタンスを作成
    /// 初期化時にディスプレイ情報を取得する
    pub fn new() -> Result<Self> {
        let mut manager = Self {
            displays: HashMap::new(),
        };
        manager.refresh_displays()?;
        Ok(manager)
    }

    /// ディスプレイ情報を更新
    /// Core Graphicsを使用して最新のディスプレイ情報を取得
    pub fn refresh_displays(&mut self) -> Result<()> {
        // TODO: Core Graphicsを使用してディスプレイ情報を取得
        // CGDisplayCreateUUIDFromDisplayIDなどのAPIを使用する
        
        log::info!("Refreshing display information");
        
        // Placeholder implementation
        self.displays.clear();
        
        Ok(())
    }

    /// すべてのディスプレイを取得
    /// 戻り値: ディスプレイ情報のマップ
    pub fn get_displays(&self) -> &HashMap<String, DisplayInfo> {
        &self.displays
    }

    /// メインディスプレイを取得
    /// 戻り値: メインディスプレイの情報（存在しない場合はNone）
    pub fn get_main_display(&self) -> Option<&DisplayInfo> {
        self.displays.values().find(|display| display.is_main)
    }

    /// UUIDでディスプレイを取得
    /// 引数: uuid - ディスプレイのUUID
    pub fn get_display_by_uuid(&self, uuid: &str) -> Option<&DisplayInfo> {
        self.displays.get(uuid)
    }

    /// ディスプレイが存在するかチェック
    /// 引数: uuid - 確認するディスプレイのUUID
    pub fn display_exists(&self, uuid: &str) -> bool {
        self.displays.contains_key(uuid)
    }

    /// ディスプレイの数を取得
    /// 戻り値: 接続されているディスプレイの総数
    pub fn get_display_count(&self) -> usize {
        self.displays.len()
    }

    /// スクリーン座標をディスプレイ座標に変換
    /// 引数: x, y - スクリーン座標
    /// 戻り値: (ディスプレイUUID, ローカルX, ローカルY)
    pub fn screen_to_display_coords(&self, x: f64, y: f64) -> Option<(String, f64, f64)> {
        for (uuid, display) in &self.displays {
            if x >= display.frame.x 
                && x < display.frame.x + display.frame.width
                && y >= display.frame.y 
                && y < display.frame.y + display.frame.height {
                let local_x = x - display.frame.x;
                let local_y = y - display.frame.y;
                return Some((uuid.clone(), local_x, local_y));
            }
        }
        None
    }

    /// ディスプレイ座標をスクリーン座標に変換
    /// 引数: uuid - ディスプレイUUID, x, y - ディスプレイ内座標
    /// 戻り値: (スクリーンX, スクリーンY)
    pub fn display_to_screen_coords(&self, uuid: &str, x: f64, y: f64) -> Option<(f64, f64)> {
        if let Some(display) = self.displays.get(uuid) {
            let screen_x = display.frame.x + x;
            let screen_y = display.frame.y + y;
            Some((screen_x, screen_y))
        } else {
            None
        }
    }
}
