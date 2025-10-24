import Foundation
import window_restore

// MARK: - Rust FFI エラーコード（型安全）

enum RustErrorCode: Int32 {
    case success = 0
    case permissionDenied = 1
    case appNotFound = 2
    case windowNotFound = 3
    case displayNotFound = 4
    case fileIO = 5
    case json = 6
    case unknown = 99

    static func from(code: Int32) -> RustErrorCode {
        switch code {
        case ERROR_SUCCESS: return .success
        case ERROR_PERMISSION_DENIED: return .permissionDenied
        case ERROR_APP_NOT_FOUND: return .appNotFound
        case ERROR_WINDOW_NOT_FOUND: return .windowNotFound
        case ERROR_DISPLAY_NOT_FOUND: return .displayNotFound
        case ERROR_FILE_IO: return .fileIO
        case ERROR_JSON: return .json
        default: return .unknown
        }
    }
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
    switch RustErrorCode.from(code: code) {
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


