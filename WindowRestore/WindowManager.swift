import Cocoa
import Foundation
import CoreGraphics
import ApplicationServices

/// ウィンドウ情報（JSON保存/読み込み対象）
struct WindowInfo: Codable {
    let ownerName: String
    let bundleIdentifier: String? // アプリの永続識別子（PIDの代替）
    let windowName: String?
    let bounds: CGRect
    let displayUUID: String?
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
            let running = NSRunningApplication(processIdentifier: pid_t(raw.pid))
            let bundleId = running?.bundleIdentifier
            return WindowInfo(
                ownerName: raw.ownerName,
                bundleIdentifier: bundleId,
                windowName: raw.windowName,
                bounds: raw.bounds,
                displayUUID: displayUUID,
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

    func layoutExists(name: String) -> Bool {
        guard let url = try? FileHelper.layoutFileURL(name: name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - 復元

    func restoreWindows(name: String) throws {
        guard hasAccessibilityPermission() else {
            throw NSError(domain: "WindowManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "アクセシビリティ権限が必要です"])
        }
        let windows = try loadWindows(name: name)
        let deduped = deduplicateForRestore(windows)
        for win in deduped {
            restoreSingleWindow(win)
            usleep(200_000)
        }
    }

    /// 同一アプリ・同一タイトル・同一ディスプレイの重複エントリを除去する。
    /// 接続中のディスプレイに一致するエントリを優先し、それ以外は先着1件のみ残す。
    private func deduplicateForRestore(_ windows: [WindowInfo]) -> [WindowInfo] {
        let connectedUUIDs: Set<String> = Set(NSScreen.screens.compactMap { screen in
            guard let displayId = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return nil }
            if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayId)?.takeRetainedValue(),
               let cfStr = CFUUIDCreateString(kCFAllocatorDefault, uuidRef) {
                return cfStr as String
            }
            return String(displayId)
        })

        // キー: bundleId(orOwnerName) + "|" + windowName + "|" + displayUUID
        // 同一キー = 同一物理ウィンドウの重複保存 → 先着1件のみ採用
        var seen = Set<String>()
        var result: [WindowInfo] = []

        // 第1パス: 接続中ディスプレイのエントリを優先
        for w in windows {
            guard let uuid = w.displayUUID, connectedUUIDs.contains(uuid) else { continue }
            let key = "\(w.bundleIdentifier ?? w.ownerName)|\(w.windowName ?? "")|\(uuid)"
            if seen.insert(key).inserted { result.append(w) }
        }
        // 第2パス: 未登録のエントリを追加（異なるディスプレイの別ウィンドウ等）
        for w in windows {
            let uuid = w.displayUUID ?? ""
            let key = "\(w.bundleIdentifier ?? w.ownerName)|\(w.windowName ?? "")|\(uuid)"
            if seen.insert(key).inserted { result.append(w) }
        }
        return result
    }

    // MARK: - マルチSpace: 追記保存/ラベルごと復元

    func saveWindowsAppend(name: String, label: String) throws {
        try FileHelper.ensureDirectories()
        let captured = fetchVisibleAppWindows().map { w in
            WindowInfo(ownerName: w.ownerName,
                       bundleIdentifier: w.bundleIdentifier,
                       windowName: w.windowName,
                       bounds: w.bounds,
                       displayUUID: w.displayUUID,
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
                       bundleIdentifier: w.bundleIdentifier,
                       windowName: w.windowName,
                       bounds: w.bounds,
                       displayUUID: w.displayUUID,
                       layoutLabel: label)
        }
        let url = try FileHelper.layoutFileURL(name: name)
        try FileHelper.saveJSON(replaced, to: url)
    }

    // MARK: - ウィンドウマッチングヘルパー

    /// タイトル一致を優先し、候補が複数 or ゼロの場合は保存座標に最も近いウィンドウを返す
    private func bestMatchWindow(
        from axWindows: [AXUIElement],
        windowName: String?,
        savedOrigin: CGPoint
    ) -> AXUIElement {
        if let expected = windowName, !expected.isEmpty {
            let matches = axWindows.filter { w in
                var ref: CFTypeRef?
                guard AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &ref) == .success,
                      let title = ref as? String else { return false }
                return title == expected
            }
            if matches.count == 1 { return matches[0] }
            if matches.count > 1 {
                // 同一タイトルが複数 → 保存座標に近い方を選ぶ
                return closestWindow(from: matches, to: savedOrigin) ?? matches[0]
            }
        }
        // タイトル不一致 or タイトルなし → 全候補から保存座標に最も近いものを選ぶ
        return closestWindow(from: axWindows, to: savedOrigin) ?? axWindows[0]
    }

    /// AXUIElement 群の中で現在位置が target に最も近いものを返す
    private func closestWindow(from windows: [AXUIElement], to target: CGPoint) -> AXUIElement? {
        var best: AXUIElement?
        var bestDist = CGFloat.infinity
        for w in windows {
            var ref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &ref) == .success,
                  ref != nil else { continue }
            // CFTypeRef → AXValue のキャストは常に成功するため as! を使用
            let axVal = ref! as! AXValue
            var pos = CGPoint.zero
            guard AXValueGetValue(axVal, .cgPoint, &pos) else { continue }
            let dist = hypot(pos.x - target.x, pos.y - target.y)
            if dist < bestDist { bestDist = dist; best = w }
        }
        return best
    }

    // MARK: - 画面外防止ヘルパー

    /// NSScreen.frame（Cocoa座標: y上向き）を CGWindow座標系（y下向き）に変換する
    private func cgWindowFrame(for screen: NSScreen) -> CGRect {
        let mainH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let f = screen.frame
        return CGRect(x: f.minX,
                      y: mainH - f.maxY,
                      width: f.width,
                      height: f.height)
    }

    /// スクリーンの displayUUID が保存値と一致するか判定する
    private func screenMatchesUUID(_ screen: NSScreen, uuid: String) -> Bool {
        guard let displayId = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return false }
        if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayId)?.takeRetainedValue(),
           let cfStr = CFUUIDCreateString(kCFAllocatorDefault, uuidRef) {
            return (cfStr as String) == uuid
        }
        return String(displayId) == uuid
    }

    /// CGWindow座標系での点→矩形間距離（点が矩形内なら0）
    private func distanceToCGFrame(_ point: CGPoint, _ frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return sqrt(dx * dx + dy * dy)
    }

    /// ウィンドウ矩形を有効なスクリーン内に収める。
    /// - preferredDisplayUUID が現在の接続済みスクリーンと一致すればそのスクリーンに配置。
    /// - 一致しない場合は既存スクリーン内に収まっていればそのまま、
    ///   完全に画面外なら最も近いスクリーンへ移動する。
    private func clampWindowToScreen(_ rect: CGRect, preferredDisplayUUID: String?) -> CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return rect }

        // 1) UUID一致スクリーンを探す
        let preferredScreen: NSScreen? = preferredDisplayUUID.flatMap { uuid in
            screens.first { screenMatchesUUID($0, uuid: uuid) }
        }

        // 2) 対象スクリーンを決定
        let targetScreen: NSScreen
        if let preferred = preferredScreen {
            // UUID一致 → そのスクリーンで確実にクランプ（解像度変更にも対応）
            targetScreen = preferred
        } else {
            // UUID不一致（モニター交換等）
            let cgFrames = screens.map { cgWindowFrame(for: $0) }
            let isOnAnyScreen = cgFrames.contains { $0.intersects(rect) }
            if isOnAnyScreen { return rect }  // 画面内に収まっていればそのまま

            // 完全に画面外 → 最も近いスクリーンへ
            let center = CGPoint(x: rect.midX, y: rect.midY)
            targetScreen = screens.min {
                distanceToCGFrame(center, cgWindowFrame(for: $0)) <
                distanceToCGFrame(center, cgWindowFrame(for: $1))
            } ?? screens[0]
        }

        // 3) targetScreen の CGWindow座標系フレームでクランプ
        let frame = cgWindowFrame(for: targetScreen)
        if frame.contains(CGPoint(x: rect.minX, y: rect.minY)) &&
           rect.maxX <= frame.maxX && rect.maxY <= frame.maxY {
            return rect  // 完全に収まっていれば変更不要
        }

        let w = min(rect.width, frame.width)
        let h = min(rect.height, frame.height)
        let x = max(frame.minX, min(rect.minX, frame.maxX - w))
        let y = max(frame.minY, min(rect.minY, frame.maxY - h))
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func restoreSingleWindow(_ info: WindowInfo) {
        // 1) bundleIdentifier があればそれを優先して現在のPID群を取得。なければ従来のPIDを使用
        var targetPids: [pid_t] = []
        if let bid = info.bundleIdentifier, !bid.isEmpty {
            var apps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
            if apps.isEmpty {
                // 未起動なら起動を試みる
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = false
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                }
                // 起動出現待ち（最大約10秒）
                var tries = 0
                while apps.isEmpty && tries < 50 {
                    usleep(200_000)
                    apps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
                    tries += 1
                }
            }
            targetPids = apps.map { pid_t($0.processIdentifier) }
        }
        if targetPids.isEmpty {
            print("[restore] 対象アプリ未起動/特定不可 owner=\(info.ownerName) bundleId=\(info.bundleIdentifier ?? "-")")
            return
        }

        // 2) 各PIDについてAXウィンドウを探索し、タイトル一致を優先
        for pid in targetPids {
            let appRef = AXUIElementCreateApplication(pid)

            var windowsValue: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue)
            guard err == .success, let axWindows = windowsValue as? [AXUIElement], !axWindows.isEmpty else {
                continue
            }

            // タイトル一致 → 複数なら保存座標に最も近いものを採用、なければ座標近似のみで選択
            let targetWindow = bestMatchWindow(
                from: axWindows,
                windowName: info.windowName,
                savedOrigin: info.bounds.origin
            )

            // 位置とサイズ設定（画面外防止クランプ適用）
            let clampedBounds = clampWindowToScreen(info.bounds, preferredDisplayUUID: info.displayUUID)
            var pos = CGPoint(x: clampedBounds.origin.x, y: clampedBounds.origin.y)
            var size = CGSize(width: clampedBounds.size.width, height: clampedBounds.size.height)

            if let posValue = AXValueCreate(.cgPoint, &pos) {
                let setPosErr = AXUIElementSetAttributeValue(targetWindow, kAXPositionAttribute as CFString, posValue)
                if setPosErr != .success { print("[restore] 位置設定失敗: \(setPosErr)") }
            }
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                let setSizeErr = AXUIElementSetAttributeValue(targetWindow, kAXSizeAttribute as CFString, sizeValue)
                if setSizeErr != .success { print("[restore] サイズ設定失敗: \(setSizeErr)") }
            }

            // 1つでも適用できたら終了
            return
        }

        print("[restore] 対象ウィンドウ未検出 owner=\(info.ownerName) bundleId=\(info.bundleIdentifier ?? "-")")
    }
}


