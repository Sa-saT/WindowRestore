import Foundation

// MARK: - レイアウト操作 API

enum APIResult<T> {
    case success(T)
    case failure(code: Int32, message: String)
}

struct LayoutAPI {
    private static let CODE_SUCCESS: Int32 = 0
    private static let CODE_PERMISSION: Int32 = 1
    private static let CODE_FILEIO: Int32 = 5
    private static let CODE_JSON: Int32 = 6
    private static let CODE_UNKNOWN: Int32 = 99

    static func initLibrary() -> APIResult<Void> {
        return .success(())
    }

    static func cleanupLibrary() {
    }

    static func saveLayout(name: String) -> APIResult<Void> {
        do {
            try WindowManager.shared.saveWindows(name: name)
            return .success(())
        } catch {
            return .failure(code: CODE_FILEIO, message: errorMessage(fallback: "レイアウトの保存に失敗しました: \(error.localizedDescription)"))
        }
    }

    static func restoreLayout(name: String) -> APIResult<Void> {
        do {
            try WindowManager.shared.restoreWindows(name: name)
            return .success(())
        } catch {
            let code: Int32 = WindowManager.shared.hasAccessibilityPermission() ? CODE_UNKNOWN : CODE_PERMISSION
            return .failure(code: code, message: errorMessage(fallback: "レイアウトの復元に失敗しました: \(error.localizedDescription)"))
        }
    }

    static func deleteLayout(name: String) -> APIResult<Void> {
        do {
            try WindowManager.shared.deleteLayout(name: name)
            return .success(())
        } catch {
            return .failure(code: CODE_FILEIO, message: errorMessage(fallback: "レイアウトの削除に失敗しました: \(error.localizedDescription)"))
        }
    }

    static func listLayouts() -> APIResult<[String]> {
        let layouts = WindowManager.shared.listLayouts()
        return .success(layouts)
    }

    static func hasAccessibilityPermission() -> Bool {
        return WindowManager.shared.hasAccessibilityPermission()
    }

    private static func errorMessage(fallback: String) -> String { fallback }
}
