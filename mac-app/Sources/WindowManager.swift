import Cocoa
import Foundation
import CoreGraphics
import ApplicationServices

/// ウィンドウ情報（JSON保存/読み込み対象）
struct WindowInfo: Codable {
    let ownerName: String
    let pid: Int
    let windowName: String?
    let bounds: CGRect
    let displayUUID: String?
    let spaceNumber: Int?
    let layoutLabel: String?
}

/// Swift単独のウィンドウ管理ロジック
final class WindowManager {
    static let shared = WindowManager()
    private init() {}

    // 除外対象の所有者名（Dock/Window Serverなど）
    private let excludedOwnerNames: Set<String> = [
        "Dock", "Window Server", "NotificationCenter", "Control Center", "Spotlight"
    ]

    // 最小ウィンドウサイズ閾値
    private let minWindowSize: CGFloat = 100.0

    // MARK: - 権限

    func hasAccessibilityPermission() -> Bool {
        // ダイアログを出さずに現在の状態のみを返す
        return AXIsProcessTrusted()
    }

    // MARK: - ウィンドウ取得

    func fetchVisibleAppWindows() -> [WindowInfo] {
        // 複数回スナップショットを取り、安定して出現するウィンドウのみ採用
        let sampleCount = 3
        let sampleIntervalUs: useconds_t = 120_000
        var samples: [[RawWindow]] = []
        for _ in 0..<sampleCount {
            samples.append(snapshotWindowsOnce())
            usleep(sampleIntervalUs)
        }
        let stabilized = consolidateWindows(samples: samples)
        let filtered = filterWindows(from: stabilized)
        return filtered.map { raw in
            let displayUUID = resolveDisplayUUID(for: raw.bounds.origin)
            return WindowInfo(
                ownerName: raw.ownerName,
                pid: raw.pid,
                windowName: raw.windowName,
                bounds: raw.bounds,
                displayUUID: displayUUID,
                spaceNumber: nil,
                layoutLabel: nil
            )
        }
    }

    // 内部表現（安定化のためにwindowNumber等を保持）
    private struct RawWindow {
        let ownerName: String
        let pid: Int
        let windowName: String?
        let bounds: CGRect
        let layer: Int
        let alpha: CGFloat
        let windowNumber: Int
    }

    private func snapshotWindowsOnce() -> [RawWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var result: [RawWindow] = []
        for dict in infoList {
            guard
                let ownerName = dict[kCGWindowOwnerName as String] as? String,
                let pid = dict[kCGWindowOwnerPID as String] as? Int,
                let layer = dict[kCGWindowLayer as String] as? Int,
                let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                let windowNumber = dict[kCGWindowNumber as String] as? Int
            else { continue }

            let alphaAny = dict[kCGWindowAlpha as String]
            let alpha: CGFloat = (alphaAny as? CGFloat)
                ?? CGFloat((alphaAny as? Double) ?? 1.0)

            let x = (boundsDict["X"] as? CGFloat) ?? CGFloat((boundsDict["X"] as? Double) ?? 0)
            let y = (boundsDict["Y"] as? CGFloat) ?? CGFloat((boundsDict["Y"] as? Double) ?? 0)
            let w = (boundsDict["Width"] as? CGFloat) ?? CGFloat((boundsDict["Width"] as? Double) ?? 0)
            let h = (boundsDict["Height"] as? CGFloat) ?? CGFloat((boundsDict["Height"] as? Double) ?? 0)
            let rect = CGRect(x: x, y: y, width: w, height: h)

            let windowName = dict[kCGWindowName as String] as? String

            result.append(RawWindow(ownerName: ownerName,
                                    pid: pid,
                                    windowName: windowName,
                                    bounds: rect,
                                    layer: layer,
                                    alpha: alpha,
                                    windowNumber: windowNumber))
        }
        return result
    }

    // 複数サンプルの出現回数で安定化（2/3以上出現）し、最新サンプルの情報で代表値を採用
    private func consolidateWindows(samples: [[RawWindow]]) -> [RawWindow] {
        guard !samples.isEmpty else { return [] }
        var countMap: [Int: Int] = [:]
        var latestMap: [Int: RawWindow] = [:]
        for sample in samples {
            for w in sample {
                countMap[w.windowNumber, default: 0] += 1
                latestMap[w.windowNumber] = w
            }
        }
        let threshold = max(1, samples.count * 2 / 3)
        var stabilized: [RawWindow] = []
        for (num, cnt) in countMap where cnt >= threshold {
            if let w = latestMap[num] {
                stabilized.append(w)
            }
        }
        return stabilized
    }

    // 表示用に安定フィルタのみ（同一アプリの複数ウィンドウを保持）
    private func filterWindows(from windows: [RawWindow]) -> [RawWindow] {
        return windows.filter { w in
            if excludedOwnerNames.contains(w.ownerName) { return false }
            if w.layer != 0 { return false }
            if w.alpha < 0.01 { return false }
            if w.bounds.width < minWindowSize || w.bounds.height < minWindowSize { return false }
            return true
        }
    }

    private func resolveDisplayUUID(for globalPoint: CGPoint) -> String? {
        for screen in NSScreen.screens {
            if screen.frame.contains(globalPoint) {
                if let displayId = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
                    if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayId)?.takeRetainedValue(),
                       let cfStr = CFUUIDCreateString(kCFAllocatorDefault, uuidRef) {
                        return cfStr as String
                    } else {
                        return String(displayId)
                    }
                }
            }
        }
        return nil
    }

    // MARK: - JSON 保存/読み込み

    func saveWindows(name: String) throws {
        try FileHelper.ensureDirectories()
        let info = fetchVisibleAppWindows()
        let url = try FileHelper.layoutFileURL(name: name)
        try FileHelper.saveJSON(info, to: url)
    }

    func loadWindows(name: String) throws -> [WindowInfo] {
        let url = try FileHelper.layoutFileURL(name: name)
        return try FileHelper.loadJSON([WindowInfo].self, from: url)
    }

    func listLayouts() -> [String] {
        return FileHelper.listLayoutNames()
    }

    func deleteLayout(name: String) throws {
        try FileHelper.deleteLayout(name: name)
    }

    // MARK: - 復元

    func restoreWindows(name: String) throws {
        guard hasAccessibilityPermission() else {
            throw NSError(domain: "WindowManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "アクセシビリティ権限が必要です"])
        }
        let windows = try loadWindows(name: name)
        for win in windows {
            restoreSingleWindow(win)
            // ウィンドウ間の僅かな間隔
            usleep(200_000)
        }
    }

    // MARK: - マルチSpace: 追記保存/ラベルごと復元

    func saveWindowsAppend(name: String, label: String) throws {
        try FileHelper.ensureDirectories()
        let captured = fetchVisibleAppWindows().map { w in
            WindowInfo(ownerName: w.ownerName,
                       pid: w.pid,
                       windowName: w.windowName,
                       bounds: w.bounds,
                       displayUUID: w.displayUUID,
                       spaceNumber: w.spaceNumber,
                       layoutLabel: label)
        }
        var existing: [WindowInfo] = []
        if let list = try? loadWindows(name: name) { existing = list }
        existing.append(contentsOf: captured)
        let url = try FileHelper.layoutFileURL(name: name)
        try FileHelper.saveJSON(existing, to: url)
    }

    func layoutLabels(in name: String) -> [String] {
        guard let list = try? loadWindows(name: name) else { return [] }
        let labels = list.compactMap { $0.layoutLabel }
        // Space<number> を数値順にソート、それ以外は文字列昇順
        return Array(Set(labels)).sorted { a, b in
            if let ai = Int(a.replacingOccurrences(of: "Space", with: "")),
               let bi = Int(b.replacingOccurrences(of: "Space", with: "")) {
                return ai < bi
            }
            return a < b
        }
    }

    func restoreWindowsForLabel(name: String, label: String) throws {
        guard hasAccessibilityPermission() else {
            throw NSError(domain: "WindowManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "アクセシビリティ権限が必要です"])
        }
        let all = try loadWindows(name: name)
        let targets = all.filter { $0.layoutLabel == label }
        for win in targets {
            restoreSingleWindow(win)
            usleep(200_000)
        }
    }

    func restoreWindowsInteractive(name: String, prompt: (String) -> Bool) throws {
        let labels = layoutLabels(in: name)
        guard !labels.isEmpty else {
            // ラベルなしは通常復元
            try restoreWindows(name: name)
            return
        }
        for label in labels {
            // プロンプトがtrueを返した場合に実行（ユーザーがSpace切替を完了した合図）
            let proceed = prompt(label)
            if !proceed { break }
            try restoreWindowsForLabel(name: name, label: label)
        }
    }

    // MARK: - 重複ラベル対処

    func hasLabel(name: String, label: String) -> Bool {
        guard let list = try? loadWindows(name: name) else { return false }
        return list.contains { $0.layoutLabel == label }
    }

    func nextAvailableLabel(name: String, baseLabel: String) -> String {
        let labels = Set(layoutLabels(in: name))
        if !labels.contains(baseLabel) { return baseLabel }
        var i = 2
        while labels.contains("\(baseLabel)-\(i)") { i += 1 }
        return "\(baseLabel)-\(i)"
    }

    func replaceWindowsForLabel(name: String, label: String, with newWindows: [WindowInfo]) throws {
        var existing: [WindowInfo] = []
        if let list = try? loadWindows(name: name) { existing = list }
        let filtered = existing.filter { $0.layoutLabel != label }
        let replaced = filtered + newWindows.map { w in
            WindowInfo(ownerName: w.ownerName,
                       pid: w.pid,
                       windowName: w.windowName,
                       bounds: w.bounds,
                       displayUUID: w.displayUUID,
                       spaceNumber: w.spaceNumber,
                       layoutLabel: label)
        }
        let url = try FileHelper.layoutFileURL(name: name)
        try FileHelper.saveJSON(replaced, to: url)
    }

    private func restoreSingleWindow(_ info: WindowInfo) {
        let appRef = AXUIElementCreateApplication(pid_t(info.pid))

        var windowsValue: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue)
        guard err == .success, let axWindows = windowsValue as? [AXUIElement], let first = axWindows.first else {
            print("[restore] ウィンドウ要素取得失敗 pid=\(info.pid) owner=\(info.ownerName)")
            return
        }

        // 位置とサイズ設定
        var pos = CGPoint(x: info.bounds.origin.x, y: info.bounds.origin.y)
        var size = CGSize(width: info.bounds.size.width, height: info.bounds.size.height)

        if let posValue = AXValueCreate(.cgPoint, &pos) {
            let setPosErr = AXUIElementSetAttributeValue(first, kAXPositionAttribute as CFString, posValue)
            if setPosErr != .success { print("[restore] 位置設定失敗: \(setPosErr)") }
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let setSizeErr = AXUIElementSetAttributeValue(first, kAXSizeAttribute as CFString, sizeValue)
            if setSizeErr != .success { print("[restore] サイズ設定失敗: \(setSizeErr)") }
        }
    }
}


