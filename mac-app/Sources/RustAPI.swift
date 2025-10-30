import Foundation

// MARK: - 型安全なRust APIラッパー

enum RustResult<T> {
    case success(T)
    case failure(code: Int32, message: String)
}

struct RustAPI {
    private static let CODE_SUCCESS: Int32 = 0
    private static let CODE_PERMISSION: Int32 = 1
    private static let CODE_FILEIO: Int32 = 5
    private static let CODE_JSON: Int32 = 6
    private static let CODE_UNKNOWN: Int32 = 99

    static func initLibrary() -> RustResult<Void> {
        // Swift単独化のため初期化は不要
        return .success(())
    }

    static func cleanupLibrary() {
        // Swift単独化のためクリーンアップは不要
    }

    static func saveLayout(name: String) -> RustResult<Void> {
        do {
            try WindowManager.shared.saveWindows(name: name)
            return .success(())
        } catch {
            return .failure(code: CODE_FILEIO, message: errorMessage(fallback: "レイアウトの保存に失敗しました: \(error.localizedDescription)"))
        }
    }

    static func restoreLayout(name: String) -> RustResult<Void> {
        do {
            try WindowManager.shared.restoreWindows(name: name)
            return .success(())
        } catch {
            // 権限不足の場合とそれ以外を大まかに分類
            let code: Int32 = WindowManager.shared.hasAccessibilityPermission() ? CODE_UNKNOWN : CODE_PERMISSION
            return .failure(code: code, message: errorMessage(fallback: "レイアウトの復元に失敗しました: \(error.localizedDescription)"))
        }
    }

    static func deleteLayout(name: String) -> RustResult<Void> {
        do {
            try WindowManager.shared.deleteLayout(name: name)
            return .success(())
        } catch {
            return .failure(code: CODE_FILEIO, message: errorMessage(fallback: "レイアウトの削除に失敗しました: \(error.localizedDescription)"))
        }
    }

    static func listLayouts() -> RustResult<[String]> {
        let layouts = WindowManager.shared.listLayouts()
        return .success(layouts)
    }

    static func hasAccessibilityPermission() -> Bool {
        return WindowManager.shared.hasAccessibilityPermission()
    }

    private static func errorMessage(fallback: String) -> String { fallback }
}


