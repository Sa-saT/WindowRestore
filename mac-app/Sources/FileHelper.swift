import Foundation

/// JSONファイル保存/読み込み用ヘルパー
/// - データディレクトリは以下の優先順で決定
///   1) 環境変数 `WINDOW_RESTORE_DATA_DIR`
///   2) `~/Library/Application Support/window_restore`
///   3) フォールバック: カレントディレクトリ/`target/window_restore`
final class FileHelper {
    enum FileHelperError: Error {
        case invalidLayoutName
        case directoryCreationFailed
    }

    // MARK: - パス解決

    static func baseDirectoryURL() -> URL {
        if let env = ProcessInfo.processInfo.environment["WINDOW_RESTORE_DATA_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true) {
            return appSupport.appendingPathComponent("window_restore", isDirectory: true)
        }
        // フォールバック
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return cwd.appendingPathComponent("target/window_restore", isDirectory: true)
    }

    static func layoutsDirectoryURL() -> URL {
        return baseDirectoryURL().appendingPathComponent("layouts", isDirectory: true)
    }

    static func configFileURL() -> URL {
        return baseDirectoryURL().appendingPathComponent("config.json", isDirectory: false)
    }

    static func layoutFileURL(name: String) throws -> URL {
        guard validateLayoutName(name) else { throw FileHelperError.invalidLayoutName }
        return layoutsDirectoryURL().appendingPathComponent("\(name).json", isDirectory: false)
    }

    // MARK: - 生成/検証

    @discardableResult
    static func ensureDirectories() throws -> URL {
        let base = baseDirectoryURL()
        let layouts = layoutsDirectoryURL()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layouts, withIntermediateDirectories: true)
        return base
    }

    static func validateLayoutName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.rangeOfCharacter(from: invalid) == nil
    }

    // MARK: - JSON I/O

    static func saveJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try ensureParentDirectory(of: url)
        try data.write(to: url, options: [.atomic])
    }

    static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    static func ensureParentDirectory(of url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - レイアウト一覧/削除

    static func listLayoutNames() -> [String] {
        let dir = layoutsDirectoryURL()
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return items
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    static func deleteLayout(name: String) throws {
        let url = try layoutFileURL(name: name)
        try FileManager.default.removeItem(at: url)
    }
}


