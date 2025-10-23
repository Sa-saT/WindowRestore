import Foundation
import window_restore

// MARK: - Rust FFI エラーコード（型安全）

enum RustErrorCode: Int32 {
    case success = ERROR_SUCCESS
    case permissionDenied = ERROR_PERMISSION_DENIED
    case appNotFound = ERROR_APP_NOT_FOUND
    case windowNotFound = ERROR_WINDOW_NOT_FOUND
    case displayNotFound = ERROR_DISPLAY_NOT_FOUND
    case fileIO = ERROR_FILE_IO
    case json = ERROR_JSON
    case unknown = ERROR_UNKNOWN
}

// MARK: - Rust エラーメッセージ取得

func rustLastError() -> String {
    if let ptr = get_last_error_message() {
        let message = String(cString: ptr)
        free_string(ptr)
        return message
    }
    return ""
}

func rustErrorMessage(code: Int32, fallback: String) -> String {
    let detail = rustLastError()
    if !detail.isEmpty { return detail }
    switch RustErrorCode(rawValue: code) ?? .unknown {
    case .permissionDenied:
        return "アクセシビリティ権限が必要です。システム設定で有効にしてください。"
    case .appNotFound:
        return "対象アプリが見つかりません。"
    case .windowNotFound:
        return "対象ウィンドウが見つかりません。"
    case .displayNotFound:
        return "対象ディスプレイが見つかりません。"
    case .fileIO:
        return "ファイル入出力エラーが発生しました。"
    case .json:
        return "データ処理中にエラーが発生しました。"
    case .success:
        return ""
    case .unknown:
        return fallback
    }
}


