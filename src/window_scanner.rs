//! Window scanning functionality for macOS
//! macOSのウィンドウスキャン機能
//! Core GraphicsとAccessibility APIを使用してウィンドウ情報を取得

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
// 未使用のインポートを削除（将来的に使用予定）
// use objc::{msg_send, sel, sel_impl};
// use cocoa::base::{id, nil};
// use cocoa::foundation::{NSArray, NSDictionary, NSString, NSUInteger};
// use objc::runtime::{Object, YES};
// use core_graphics::display::{CGDisplay, CGMainDisplayID};
use core_foundation::{
    base::{CFRelease, CFTypeRef},
    dictionary::{CFDictionaryRef, CFDictionaryGetValue, CFDictionaryContainsKey},
    string::{CFStringRef, CFStringGetCString, CFStringGetLength, CFStringCreateWithCString},
    number::{CFNumberRef, CFNumberGetValue},
    array::{CFArrayGetCount, CFArrayGetValueAtIndex},
};
use core_graphics::window::{CGWindowListCopyWindowInfo, kCGWindowListOptionOnScreenOnly, kCGNullWindowID};

/// ウィンドウレベルの列挙型
/// macOSのウィンドウの階層を表す
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "PascalCase")]
pub enum WindowLevel {
    Normal = 0,    // 通常のウィンドウ
    Floating = 3,  // フローティングウィンドウ
    Modal = 8,     // モーダルダイアログ
    Dock = 20,     // Dockのウィンドウ
}

/// ウィンドウ情報構造体
/// 各ウィンドウの詳細情報を保持
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowInfo {
    pub app_name: String,        // アプリケーション名
    pub bundle_id: String,       // バンドルID（例: com.apple.finder）
    pub title: String,           // ウィンドウタイトル
    pub frame: WindowFrame,      // ウィンドウの位置とサイズ
    pub display_uuid: String,    // 所属ディスプレイのUUID
    pub window_level: WindowLevel, // ウィンドウレベル
    pub is_minimized: bool,      // 最小化されているか
    pub is_hidden: bool,         // 非表示か
}

/// ウィンドウフレーム構造体
/// ウィンドウの位置とサイズを表す
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowFrame {
    pub x: f64,      // X座標
    pub y: f64,      // Y座標
    pub width: f64,  // 幅
    pub height: f64, // 高さ
}

/// macOS用ウィンドウスキャナー
/// システム上のすべてのウィンドウを検索・取得する
pub struct WindowScanner {
    // ウィンドウスキャンの内部状態
}

impl WindowScanner {
    /// 新しいWindowScannerインスタンスを作成
    pub fn new() -> Result<Self> {
        // TODO: ウィンドウスキャン機能を初期化
        Ok(Self {})
    }

    /// すべての表示中のウィンドウをスキャン
    /// 戻り値: ウィンドウ情報の配列
    pub fn scan_windows(&self) -> Result<Vec<WindowInfo>> {
        unsafe {
            let window_list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
            
            let mut windows = Vec::new();

            for i in 0..CFArrayGetCount(window_list) {
                let window_dict: CFDictionaryRef = CFArrayGetValueAtIndex(window_list, i) as CFDictionaryRef;
                let window: WindowInfo = Self::parse_window(window_dict)?;
                windows.push(window);
            }

            CFRelease(window_list as CFTypeRef);
            Ok(windows)
        }
    }

    /// ディスプレイ情報を取得
    /// 戻り値: ディスプレイUUIDをキーとするディスプレイ情報のマップ
    pub fn get_displays(&self) -> Result<HashMap<String, DisplayInfo>> {
        // TODO: ディスプレイ情報の取得を実装
        Ok(HashMap::new())
    }

    /// ウィンドウ情報をパース
    /// Core Graphicsから取得した辞書データをWindowInfo構造体に変換
    fn parse_window(window_dict: CFDictionaryRef) -> Result<WindowInfo> {
        use core_foundation::base::{kCFAllocatorDefault};
        
        unsafe {
            // ウィンドウIDを取得
            let window_id_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"kCGWindowNumber\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let window_id = if CFDictionaryContainsKey(window_dict, window_id_key as *const std::ffi::c_void) != 0 {
                let window_id_ref = CFDictionaryGetValue(window_dict, window_id_key as *const std::ffi::c_void);
                let mut window_id: i32 = 0;
                if CFNumberGetValue(window_id_ref as CFNumberRef, core_foundation::number::kCFNumberSInt32Type, &mut window_id as *mut i32 as *mut std::ffi::c_void) {
                    window_id
                } else {
                    0
                }
            } else {
                0
            };
            CFRelease(window_id_key as CFTypeRef);

            // アプリケーション名を取得
            let app_name_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"kCGWindowOwnerName\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let app_name = if CFDictionaryContainsKey(window_dict, app_name_key as *const std::ffi::c_void) != 0 {
                let app_name_ref = CFDictionaryGetValue(window_dict, app_name_key as *const std::ffi::c_void);
                Self::cf_string_to_string(app_name_ref as CFStringRef)
            } else {
                "Unknown".to_string()
            };
            CFRelease(app_name_key as CFTypeRef);

            // バンドルIDを取得（PIDから生成）
            let bundle_id_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"kCGWindowOwnerPID\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let bundle_id = if CFDictionaryContainsKey(window_dict, bundle_id_key as *const std::ffi::c_void) != 0 {
                let bundle_id_ref = CFDictionaryGetValue(window_dict, bundle_id_key as *const std::ffi::c_void);
                let mut pid: i32 = 0;
                if CFNumberGetValue(bundle_id_ref as CFNumberRef, core_foundation::number::kCFNumberSInt32Type, &mut pid as *mut i32 as *mut std::ffi::c_void) {
                    format!("com.app.{}", pid)
                } else {
                    "unknown".to_string()
                }
            } else {
                "unknown".to_string()
            };
            CFRelease(bundle_id_key as CFTypeRef);

            // ウィンドウタイトルを取得
            let title_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"kCGWindowName\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let title = if CFDictionaryContainsKey(window_dict, title_key as *const std::ffi::c_void) != 0 {
                let title_ref = CFDictionaryGetValue(window_dict, title_key as *const std::ffi::c_void);
                Self::cf_string_to_string(title_ref as CFStringRef)
            } else {
                "Untitled".to_string()
            };
            CFRelease(title_key as CFTypeRef);

            // ウィンドウフレームを取得
            let bounds_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"kCGWindowBounds\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let frame = if CFDictionaryContainsKey(window_dict, bounds_key as *const std::ffi::c_void) != 0 {
                let bounds_ref = CFDictionaryGetValue(window_dict, bounds_key as *const std::ffi::c_void);
                Self::parse_bounds(bounds_ref as CFDictionaryRef)?
            } else {
                WindowFrame { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
            };
            CFRelease(bounds_key as CFTypeRef);

            // ウィンドウレベルを取得
            let level_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"kCGWindowLayer\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let window_level = if CFDictionaryContainsKey(window_dict, level_key as *const std::ffi::c_void) != 0 {
                let level_ref = CFDictionaryGetValue(window_dict, level_key as *const std::ffi::c_void);
                let mut level: i32 = 0;
                if CFNumberGetValue(level_ref as CFNumberRef, core_foundation::number::kCFNumberSInt32Type, &mut level as *mut i32 as *mut std::ffi::c_void) {
                    match level {
                        0 => WindowLevel::Normal,
                        3 => WindowLevel::Floating,
                        8 => WindowLevel::Modal,
                        20 => WindowLevel::Dock,
                        _ => WindowLevel::Normal,
                    }
                } else {
                    WindowLevel::Normal
                }
            } else {
                WindowLevel::Normal
            };
            CFRelease(level_key as CFTypeRef);

            // 最小化・非表示状態を取得
            let is_minimized = false; // TODO: 最小化状態の判定を実装
            let is_hidden = false;    // TODO: 非表示状態の判定を実装

            Ok(WindowInfo {
                app_name,
                bundle_id,
                title,
                frame,
                display_uuid: "main".to_string(), // TODO: 実際のディスプレイUUIDを取得
                window_level,
                is_minimized,
                is_hidden,
            })
        }
    }

    /// CFStringをRustのStringに変換
    fn cf_string_to_string(cf_string: CFStringRef) -> String {
        unsafe {
            let length = CFStringGetLength(cf_string);
            let mut buffer = vec![0u8; (length + 1) as usize];
            let success = CFStringGetCString(
                cf_string,
                buffer.as_mut_ptr() as *mut i8,
                buffer.len() as isize,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            
            if success != 0 {
                buffer.truncate(length as usize);
                String::from_utf8_lossy(&buffer).to_string()
            } else {
                "Unknown".to_string()
            }
        }
    }

    /// 境界辞書からWindowFrameを解析
    fn parse_bounds(bounds_dict: CFDictionaryRef) -> Result<WindowFrame> {
        use core_foundation::base::{kCFAllocatorDefault};
        
        unsafe {
            let x_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"X\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let y_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"Y\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let width_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"Width\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );
            let height_key = CFStringCreateWithCString(
                kCFAllocatorDefault,
                b"Height\0".as_ptr() as *const i8,
                core_foundation::string::kCFStringEncodingUTF8,
            );

            let x = if CFDictionaryContainsKey(bounds_dict, x_key as *const std::ffi::c_void) != 0 {
                let x_ref = CFDictionaryGetValue(bounds_dict, x_key as *const std::ffi::c_void);
                let mut x: f64 = 0.0;
                CFNumberGetValue(x_ref as CFNumberRef, core_foundation::number::kCFNumberDoubleType, &mut x as *mut f64 as *mut std::ffi::c_void);
                x
            } else {
                0.0
            };
            CFRelease(x_key as CFTypeRef);

            let y = if CFDictionaryContainsKey(bounds_dict, y_key as *const std::ffi::c_void) != 0 {
                let y_ref = CFDictionaryGetValue(bounds_dict, y_key as *const std::ffi::c_void);
                let mut y: f64 = 0.0;
                CFNumberGetValue(y_ref as CFNumberRef, core_foundation::number::kCFNumberDoubleType, &mut y as *mut f64 as *mut std::ffi::c_void);
                y
            } else {
                0.0
            };
            CFRelease(y_key as CFTypeRef);

            let width = if CFDictionaryContainsKey(bounds_dict, width_key as *const std::ffi::c_void) != 0 {
                let width_ref = CFDictionaryGetValue(bounds_dict, width_key as *const std::ffi::c_void);
                let mut width: f64 = 0.0;
                CFNumberGetValue(width_ref as CFNumberRef, core_foundation::number::kCFNumberDoubleType, &mut width as *mut f64 as *mut std::ffi::c_void);
                width
            } else {
                0.0
            };
            CFRelease(width_key as CFTypeRef);

            let height = if CFDictionaryContainsKey(bounds_dict, height_key as *const std::ffi::c_void) != 0 {
                let height_ref = CFDictionaryGetValue(bounds_dict, height_key as *const std::ffi::c_void);
                let mut height: f64 = 0.0;
                CFNumberGetValue(height_ref as CFNumberRef, core_foundation::number::kCFNumberDoubleType, &mut height as *mut f64 as *mut std::ffi::c_void);
                height
            } else {
                0.0
            };
            CFRelease(height_key as CFTypeRef);

            Ok(WindowFrame { x, y, width, height })
        }
    }
}

/// ディスプレイ情報構造体
/// 接続されている各ディスプレイの情報を保持
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayInfo {
    pub uuid: String,       // ディスプレイのUUID
    pub name: String,       // ディスプレイ名
    pub frame: WindowFrame, // ディスプレイのフレーム（位置とサイズ）
    pub is_main: bool,      // メインディスプレイかどうか
}
