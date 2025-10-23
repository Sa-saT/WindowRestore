import Foundation
import window_restore

// MARK: - 型安全なRust APIラッパー

enum RustResult<T> {
    case success(T)
    case failure(code: Int32, message: String)
}

struct RustAPI {
    static func initLibrary() -> RustResult<Void> {
        let code = init_library()
        if code == ERROR_SUCCESS { return .success(()) }
        return .failure(code: code, message: rustErrorMessage(code: code, fallback: "Rustライブラリの初期化に失敗しました"))
    }

    static func cleanupLibrary() {
        _ = cleanup_library()
    }

    static func saveLayout(name: String) -> RustResult<Void> {
        let code = name.withCString { save_current_layout($0) }
        if code == ERROR_SUCCESS { return .success(()) }
        return .failure(code: code, message: rustErrorMessage(code: code, fallback: "レイアウトの保存に失敗しました"))
    }

    static func restoreLayout(name: String) -> RustResult<Void> {
        let code = name.withCString { restore_layout($0) }
        if code == ERROR_SUCCESS { return .success(()) }
        return .failure(code: code, message: rustErrorMessage(code: code, fallback: "レイアウトの復元に失敗しました"))
    }

    static func deleteLayout(name: String) -> RustResult<Void> {
        let code = name.withCString { delete_layout($0) }
        if code == ERROR_SUCCESS { return .success(()) }
        return .failure(code: code, message: rustErrorMessage(code: code, fallback: "レイアウトの削除に失敗しました"))
    }

    static func listLayouts() -> RustResult<[String]> {
        guard let ptr = get_layout_list() else {
            return .failure(code: ERROR_UNKNOWN, message: rustErrorMessage(code: ERROR_UNKNOWN, fallback: "レイアウト一覧の取得に失敗しました"))
        }
        let json = String(cString: ptr)
        free_string(ptr)
        if let data = json.data(using: .utf8),
           let array = (try? JSONSerialization.jsonObject(with: data)) as? [String] {
            return .success(array)
        }
        return .failure(code: ERROR_JSON, message: rustErrorMessage(code: ERROR_JSON, fallback: "レイアウト一覧のパースに失敗しました"))
    }

    static func hasAccessibilityPermission() -> Bool {
        return check_permissions() == ERROR_SUCCESS
    }
}


