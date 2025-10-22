//! FFI (Foreign Function Interface) bindings for C/Swift integration

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use anyhow::Result;

use crate::{WindowRestore, WindowRestoreError};

/// Error codes for FFI
pub const ERROR_SUCCESS: i32 = 0;
pub const ERROR_PERMISSION_DENIED: i32 = 1;
pub const ERROR_APP_NOT_FOUND: i32 = 2;
pub const ERROR_WINDOW_NOT_FOUND: i32 = 3;
pub const ERROR_DISPLAY_NOT_FOUND: i32 = 4;
pub const ERROR_FILE_IO: i32 = 5;
pub const ERROR_JSON: i32 = 6;
pub const ERROR_UNKNOWN: i32 = 99;

/// Convert Rust Result to FFI error code
fn result_to_error_code(result: &Result<()>) -> i32 {
    match result {
        Ok(_) => ERROR_SUCCESS,
        Err(e) => {
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

/// Save current window layout
#[no_mangle]
pub extern "C" fn save_current_layout(name: *const c_char) -> i32 {
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_UNKNOWN,
        }
    };

    match WindowRestore::new() {
        Ok(app) => {
            let result = app.save_layout(name_str);
            result_to_error_code(&result)
        }
        Err(_) => ERROR_UNKNOWN,
    }
}

/// Restore window layout
#[no_mangle]
pub extern "C" fn restore_layout(name: *const c_char) -> i32 {
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_UNKNOWN,
        }
    };

    match WindowRestore::new() {
        Ok(app) => {
            let result = app.restore_layout(name_str);
            result_to_error_code(&result)
        }
        Err(_) => ERROR_UNKNOWN,
    }
}

/// Get list of saved layouts
#[no_mangle]
pub extern "C" fn get_layout_list() -> *mut c_char {
    match WindowRestore::new() {
        Ok(app) => {
            match app.get_layout_list() {
                Ok(layouts) => {
                    let json = serde_json::to_string(&layouts).unwrap_or_else(|_| "[]".to_string());
                    CString::new(json).unwrap().into_raw()
                }
                Err(_) => CString::new("[]").unwrap().into_raw(),
            }
        }
        Err(_) => CString::new("[]").unwrap().into_raw(),
    }
}

/// Delete layout
#[no_mangle]
pub extern "C" fn delete_layout(name: *const c_char) -> i32 {
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_UNKNOWN,
        }
    };

    match WindowRestore::new() {
        Ok(app) => {
            let result = app.delete_layout(name_str);
            result_to_error_code(&result)
        }
        Err(_) => ERROR_UNKNOWN,
    }
}

/// Check if accessibility permissions are granted
#[no_mangle]
pub extern "C" fn check_permissions() -> i32 {
    match WindowRestore::new() {
        Ok(app) => {
            if app.check_permissions() {
                ERROR_SUCCESS
            } else {
                ERROR_PERMISSION_DENIED
            }
        }
        Err(_) => ERROR_UNKNOWN,
    }
}

/// Free memory allocated by get_layout_list
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

/// Initialize the library
#[no_mangle]
pub extern "C" fn init_library() -> i32 {
    // Initialize logging
    env_logger::init();
    log::info!("Window Restore library initialized");
    ERROR_SUCCESS
}

/// Cleanup the library
#[no_mangle]
pub extern "C" fn cleanup_library() -> i32 {
    log::info!("Window Restore library cleanup");
    ERROR_SUCCESS
}
