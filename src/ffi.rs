//! FFI (Foreign Function Interface) bindings for C/Swift integration
//! SwiftやObjective-CからRustの機能を呼び出すためのインターフェース

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};
use anyhow::Result;

use crate::{WindowRestore, WindowRestoreError};
use crate::layout_manager::LayoutManager;
use crate::window_scanner::WindowScanner;

// 直近のエラーメッセージをFFIで取り出せるように保持
static LAST_ERROR_MESSAGE: OnceLock<Mutex<Option<String>>> = OnceLock::new();

fn set_last_error_message(message: String) {
    let mutex = LAST_ERROR_MESSAGE.get_or_init(|| Mutex::new(None));
    if let Ok(mut guard) = mutex.lock() { *guard = Some(message); }
}

fn clear_last_error_message() {
    let mutex = LAST_ERROR_MESSAGE.get_or_init(|| Mutex::new(None));
    if let Ok(mut guard) = mutex.lock() { *guard = None; }
}

/// FFI用エラーコード
/// Swiftから呼び出した結果を判定するために使用
pub const ERROR_SUCCESS: i32 = 0;              // 成功
pub const ERROR_PERMISSION_DENIED: i32 = 1;    // 権限エラー
pub const ERROR_APP_NOT_FOUND: i32 = 2;        // アプリが見つからない
pub const ERROR_WINDOW_NOT_FOUND: i32 = 3;     // ウィンドウが見つからない
pub const ERROR_DISPLAY_NOT_FOUND: i32 = 4;    // ディスプレイが見つからない
pub const ERROR_FILE_IO: i32 = 5;              // ファイルI/Oエラー
pub const ERROR_JSON: i32 = 6;                 // JSON処理エラー
pub const ERROR_UNKNOWN: i32 = 99;             // 未知のエラー

/// RustのResult型をFFIエラーコードに変換
/// Swift側で扱いやすい整数値に変換する
fn result_to_error_code(result: &Result<()>) -> i32 {
    match result {
        Ok(_) => ERROR_SUCCESS,
        Err(e) => {
            set_last_error_message(format!("{}", e));
            if let Some(window_restore_error) = e.downcast_ref::<WindowRestoreError>() {
                match window_restore_error {
                    WindowRestoreError::PermissionDenied(_) => ERROR_PERMISSION_DENIED,
                    WindowRestoreError::AppNotFound(_) => ERROR_APP_NOT_FOUND,
                    WindowRestoreError::WindowNotFound(_) => ERROR_WINDOW_NOT_FOUND,
                    WindowRestoreError::DisplayNotFound(_) => ERROR_DISPLAY_NOT_FOUND,
                    WindowRestoreError::FileIOError(_) => ERROR_FILE_IO,
                    WindowRestoreError::JsonError(_) => ERROR_JSON,
                }
            } else {
                ERROR_UNKNOWN
            }
        }
    }
}

/// 現在のウィンドウレイアウトを保存
/// Swift/Objective-Cから呼び出し可能なC互換関数
/// 引数: name - レイアウト名（C文字列）
/// 戻り値: エラーコード（0=成功、その他=エラー）
#[no_mangle]
pub extern "C" fn save_current_layout(name: *const c_char) -> i32 {
    if name.is_null() { return ERROR_UNKNOWN; }
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_UNKNOWN,
        }
    };
    clear_last_error_message();

    // WindowRestoreの初期化に依存しない保存経路
    log::info!("FFI save_current_layout called");
    let result: Result<()> = (|| {
        let manager = LayoutManager::new()?;
        let scanner = WindowScanner::new()?;
        let windows = match scanner.scan_windows() {
            Ok(ws) => ws,
            Err(e) => {
                log::warn!("Window scan failed, saving empty layout: {}", e);
                Vec::new()
            }
        };
        // 無効なウィンドウ（タイトル等が空）を除外して保存
        let filtered: Vec<_> = windows
            .into_iter()
            .filter(|w| {
                let title_ok = !w.title.trim().is_empty();
                let app_ok = !w.app_name.trim().is_empty();
                let uuid_ok = !w.display_uuid.trim().is_empty();
                let frame_ok = w.frame.width.is_finite()
                    && w.frame.height.is_finite()
                    && w.frame.width >= 0.0
                    && w.frame.height >= 0.0
                    && w.frame.x.is_finite()
                    && w.frame.y.is_finite();
                if !(title_ok && app_ok && uuid_ok && frame_ok) {
                    log::debug!(
                        "Dropping invalid window: app='{}' title='{}' uuid='{}'",
                        w.app_name, w.title, w.display_uuid
                    );
                }
                title_ok && app_ok && uuid_ok && frame_ok
            })
            .collect();

        let r = manager.save_layout(name_str, &filtered);
        if r.is_ok() { log::info!("FFI save_current_layout succeeded: {}", name_str); }
        r
    })();
    result_to_error_code(&result)
}

/// ウィンドウレイアウトを復元
/// 指定された名前のレイアウトをロードして適用する
/// 引数: name - レイアウト名（C文字列）
/// 戻り値: エラーコード（0=成功、その他=エラー）
#[no_mangle]
pub extern "C" fn restore_layout(name: *const c_char) -> i32 {
    if name.is_null() { return ERROR_UNKNOWN; }
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_UNKNOWN,
        }
    };
    clear_last_error_message();

    match WindowRestore::new() {
        Ok(mut app) => {
            let result = app.restore_layout(name_str);
            result_to_error_code(&result)
        }
        Err(_) => ERROR_UNKNOWN,
    }
}

/// 保存されたレイアウトのリストを取得
/// JSON配列形式の文字列を返す（例: ["Layout1", "Layout2"]）
/// 戻り値: JSON文字列のポインタ（使用後はfree_string()で解放すること）
#[no_mangle]
pub extern "C" fn get_layout_list() -> *mut c_char {
    clear_last_error_message();
    let json = (|| -> Result<String> {
        let manager = LayoutManager::new()?;
        let layouts = manager.list_layouts()?;
        log::info!("FFI get_layout_list count={}", layouts.len());
        Ok(serde_json::to_string(&layouts).unwrap_or_else(|_| "[]".to_string()))
    })().unwrap_or_else(|e| { set_last_error_message(format!("{}", e)); "[]".to_string() });
    CString::new(json).unwrap().into_raw()
}

/// レイアウトを削除
/// 指定された名前のレイアウトファイルを削除する
/// 引数: name - レイアウト名（C文字列）
/// 戻り値: エラーコード（0=成功、その他=エラー）
#[no_mangle]
pub extern "C" fn delete_layout(name: *const c_char) -> i32 {
    if name.is_null() { return ERROR_UNKNOWN; }
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_UNKNOWN,
        }
    };
    clear_last_error_message();

    let result: Result<()> = (|| {
        let manager = LayoutManager::new()?;
        let r = manager.delete_layout(name_str);
        if r.is_ok() { log::info!("FFI delete_layout succeeded: {}", name_str); }
        r
    })();
    result_to_error_code(&result)
}

/// アクセシビリティ権限をチェック
/// macOSのアクセシビリティ権限が付与されているか確認する
/// 戻り値: 0=権限あり、1=権限なし、99=エラー
#[no_mangle]
pub extern "C" fn check_permissions() -> i32 {
    clear_last_error_message();
    match WindowRestore::new() {
        Ok(app) => {
            if app.check_permissions() {
                ERROR_SUCCESS
            } else {
                ERROR_PERMISSION_DENIED
            }
        }
        Err(e) => { set_last_error_message(format!("{}", e)); ERROR_UNKNOWN },
    }
}

/// get_layout_listで割り当てられたメモリを解放
/// Swiftで文字列を使い終わった後に必ず呼び出すこと
/// 引数: s - 解放する文字列のポインタ
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

/// ライブラリを初期化
/// アプリケーション起動時に一度だけ呼び出す
/// ロギングシステムなどの初期化を行う
#[no_mangle]
pub extern "C" fn init_library() -> i32 {
    // ロギングシステムの初期化
    let _ = env_logger::try_init(); // 二重初期化時は無視
    log::info!("Window Restore library initialized");
    ERROR_SUCCESS
}

/// ライブラリのクリーンアップ
/// アプリケーション終了時に呼び出す
#[no_mangle]
pub extern "C" fn cleanup_library() -> i32 {
    log::info!("Window Restore library cleanup");
    ERROR_SUCCESS
}

/// 直近のエラーメッセージを取得
/// 戻り値: C文字列ポインタ（使用後はfree_stringで解放）
#[no_mangle]
pub extern "C" fn get_last_error_message() -> *mut c_char {
    let mutex = LAST_ERROR_MESSAGE.get_or_init(|| Mutex::new(None));
    if let Ok(guard) = mutex.lock() {
        if let Some(message) = &*guard {
            return CString::new(message.as_str()).unwrap_or_else(|_| CString::new("unknown error").unwrap()).into_raw();
        }
    }
    CString::new("").unwrap().into_raw()
}
