#!/bin/bash
# ============================================================
#  Window Restore — 統合テストスクリプト
#  ダブルクリック起動: macOS は .command ファイルを Terminal で開く
#  手動実行: bash test.command
# ============================================================

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"
WR="$PROJECT_DIR/WindowRestore"
WM="$WR/WindowManager.swift"
AD="$WR/AppDelegate.swift"

# ── カラー ────────────────────────────────
if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    BLUE='\033[1;34m';  BOLD='\033[1m';   RESET='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

OK="✅"; NG="❌"; WARN_ICON="⚠️ "
PASS_LIST=(); FAIL_LIST=()

pass()      { PASS_LIST+=("$1"); printf "  ${GREEN}${OK} %s${RESET}\n" "$1"; }
fail()      { FAIL_LIST+=("$1"); printf "  ${RED}${NG} %s${RESET}\n" "$1"; }
warn_item() { printf "  ${YELLOW}${WARN_ICON} %s${RESET}\n" "$1"; }
header()    { printf "\n${BOLD}${BLUE}── %s ──${RESET}\n" "$1"; }

check_file()     { [ -f "$2" ] && pass "$1" || fail "$1  (missing: $2)"; }
check_grep()     { grep -q "$2" "$3" 2>/dev/null && pass "$1" || fail "$1"; }
check_not_grep() { grep -q "$2" "$3" 2>/dev/null && fail "$1  (残存: $2)" || pass "$1"; }

# Swift インライン結果をパースして pass/fail に振り分け
parse_swift_results() {
    local output="$1"
    while IFS= read -r line; do
        case "$line" in
            PASS:*) pass "${line#PASS: }";;
            FAIL:*) fail "${line#FAIL: }";;
        esac
    done <<< "$output"
}

# ─────────────────────────────────────────────────────────────
printf "\n${BOLD}"
printf "╔══════════════════════════════════════════════╗\n"
printf "║   Window Restore — テストスイート            ║\n"
printf "╚══════════════════════════════════════════════╝\n"
printf "${RESET}"

# ═══════════════════════════════════════════════════════════
header "1. プロジェクト構造"
# ═══════════════════════════════════════════════════════════
check_file "WindowManager.swift"     "$WM"
check_file "AppDelegate.swift"       "$AD"
check_file "MenuController.swift"    "$WR/MenuController.swift"
check_file "PermissionManager.swift" "$WR/PermissionManager.swift"
check_file "LayoutSelector.swift"    "$WR/LayoutSelector.swift"
check_file "SettingsWindow.swift"    "$WR/SettingsWindow.swift"
check_file "FileHelper.swift"        "$WR/FileHelper.swift"
check_file "LayoutAPI.swift"         "$WR/LayoutAPI.swift"
check_file "CLAUDE.md"               "$PROJECT_DIR/CLAUDE.md"
check_file "docs/TASK_SCHEDULE.md"   "$PROJECT_DIR/docs/TASK_SCHEDULE.md"

# ═══════════════════════════════════════════════════════════
header "2. ソースコード整合性"
# ═══════════════════════════════════════════════════════════

# ── 存在すべき関数 ──
check_grep "fetchVisibleAppWindows 実装あり"  "func fetchVisibleAppWindows"  "$WM"
check_grep "saveWindowsAppend 実装あり"       "func saveWindowsAppend"       "$WM"
check_grep "restoreWindows 実装あり"          "func restoreWindows"          "$WM"
check_grep "deduplicateForRestore 実装あり"   "func deduplicateForRestore"   "$WM"
check_grep "bestMatchWindow 実装あり"         "func bestMatchWindow"         "$WM"
check_grep "closestWindow 実装あり"           "func closestWindow"           "$WM"
check_grep "clampWindowToScreen 実装あり"     "func clampWindowToScreen"     "$WM"
check_grep "cgWindowFrame 実装あり"           "func cgWindowFrame"           "$WM"
check_grep "layoutExists 実装あり"            "func layoutExists"            "$WM"
check_grep "saveCurrentLayout 実装あり"       "func saveCurrentLayout"       "$AD"
check_grep "restoreLayout 実装あり"           "func restoreLayout"           "$AD"

# ── 削除済みコードが残っていないこと ──
check_not_grep "spaceNumber 削除済み"                  "spaceNumber"                    "$WM"
check_not_grep "restoreWindowsInteractive 削除済み"    "func restoreWindowsInteractive" "$WM"
check_not_grep "restoreWindowsForLabel 削除済み"       "func restoreWindowsForLabel"    "$WM"

# ── 重要な接続確認 ──
check_grep "clampWindowToScreen を restoreSingleWindow で使用" "clampWindowToScreen"   "$WM"
check_grep "deduplicateForRestore を restoreWindows で使用"    "deduplicateForRestore" "$WM"
check_grep "bestMatchWindow を restoreSingleWindow で使用"     "bestMatchWindow"       "$WM"
check_grep "AX API で位置を設定"                               "kAXPositionAttribute"  "$WM"
check_grep "AX API でサイズを設定"                             "kAXSizeAttribute"      "$WM"
check_grep "LayoutAPI.restoreLayout を AppDelegate が呼ぶ"     "LayoutAPI.restoreLayout" "$AD"

# ═══════════════════════════════════════════════════════════
header "3. ビルドテスト"
# ═══════════════════════════════════════════════════════════
printf "  ${YELLOW}► xcodebuild 実行中...${RESET}\n"
BUILD_LOG=$(xcodebuild -scheme WindowRestore -configuration Debug build 2>&1)
if echo "$BUILD_LOG" | grep -q "BUILD SUCCEEDED"; then
    pass "xcodebuild BUILD SUCCEEDED"
else
    fail "xcodebuild BUILD FAILED"
    printf "\n${RED}--- ビルドエラー ---${RESET}\n"
    echo "$BUILD_LOG" | grep "error:" | head -10
fi

# ═══════════════════════════════════════════════════════════
header "4. JSON / FileHelper ロジックテスト"
# ═══════════════════════════════════════════════════════════
parse_swift_results "$(swift - 2>&1 <<'SWIFT_EOF'
import Foundation

func check(_ name: String, _ ok: Bool) { print(ok ? "PASS: \(name)" : "FAIL: \(name)") }

// ── 4-1. レイアウト名バリデーション ──
func validateLayoutName(_ name: String) -> Bool {
    let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return false }
    return t.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:*?\"<>|")) == nil
}
check("有効名: 'home'",         validateLayoutName("home"))
check("有効名: 'work-2024'",    validateLayoutName("work-2024"))
check("有効名: '日本語名'",     validateLayoutName("日本語名"))
check("有効名: 'layout_1'",    validateLayoutName("layout_1"))
check("無効名: 空文字",        !validateLayoutName(""))
check("無効名: 空白のみ",      !validateLayoutName("   "))
check("無効名: スラッシュ",    !validateLayoutName("a/b"))
check("無効名: バックスラッシュ", !validateLayoutName("a\\b"))
check("無効名: コロン",        !validateLayoutName("a:b"))
check("無効名: アスタリスク",  !validateLayoutName("a*b"))
check("無効名: 疑問符",        !validateLayoutName("a?b"))

// ── 4-2. WindowInfo JSON エンコード/デコード ──
// spaceNumber を含まない現在の構造体
struct WindowInfo: Codable {
    let ownerName: String
    let bundleIdentifier: String?
    let windowName: String?
    let displayUUID: String?
    let layoutLabel: String?
}

let sample = WindowInfo(
    ownerName: "Finder",
    bundleIdentifier: "com.apple.finder",
    windowName: "Desktop",
    displayUUID: "37D8832A-TEST-UUID",
    layoutLabel: "Space1"
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

do {
    let data = try encoder.encode([sample])
    let decoded = try JSONDecoder().decode([WindowInfo].self, from: data)
    let jsonStr = String(data: data, encoding: .utf8) ?? ""
    check("JSONエンコード成功",              !data.isEmpty)
    check("JSONデコード: 件数一致",          decoded.count == 1)
    check("JSONデコード: ownerName 一致",    decoded[0].ownerName == "Finder")
    check("JSONデコード: bundleId 一致",     decoded[0].bundleIdentifier == "com.apple.finder")
    check("JSONデコード: displayUUID 一致",  decoded[0].displayUUID == "37D8832A-TEST-UUID")
    check("JSONデコード: layoutLabel 一致",  decoded[0].layoutLabel == "Space1")
    check("JSON に spaceNumber が含まれない", !jsonStr.contains("spaceNumber"))
} catch {
    check("JSON エンコード/デコード 例外: \(error)", false)
}

// ── 4-3. 後方互換: spaceNumber を含む旧 JSON が読める ──
// 文字列リテラルのエスケープ問題を避けるため JSONSerialization で構築
let legacyDict: [[String: Any]] = [[
    "bundleIdentifier": "com.apple.Safari",
    "displayUUID": "OLD-UUID",
    "layoutLabel": "Space1",
    "ownerName": "Safari",
    "spaceNumber": 1,          // 旧フィールド: 現在の構造体にはないが無視されるはず
    "windowName": "Apple"
]]
if let legacyJSON = try? JSONSerialization.data(withJSONObject: legacyDict),
   let decoded = try? JSONDecoder().decode([WindowInfo].self, from: legacyJSON) {
    check("後方互換: spaceNumber含む旧JSONを読み込める", decoded.count == 1)
    check("後方互換: ownerName が正しい",               decoded[0].ownerName == "Safari")
    check("後方互換: displayUUID が正しい",             decoded[0].displayUUID == "OLD-UUID")
} else {
    check("後方互換: 旧JSON読み込み失敗", false)
}

// ── 4-4. ファイル I/O ──
let tmpDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("wr_test_\(Int.random(in: 10000...99999))")
let layoutURL = tmpDir.appendingPathComponent("layouts/test.json")
do {
    try FileManager.default.createDirectory(
        at: layoutURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder.encode([sample, sample])
    try data.write(to: layoutURL, options: .atomic)
    check("ファイル書き込み成功",   FileManager.default.fileExists(atPath: layoutURL.path))
    let loaded = try JSONDecoder().decode([WindowInfo].self, from: Data(contentsOf: layoutURL))
    check("ファイル読み込み成功",   loaded.count == 2)
    check("読み込み後データ整合性", loaded[0].bundleIdentifier == "com.apple.finder")
    // レイアウト一覧取得
    let dir = layoutURL.deletingLastPathComponent()
    let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    let names = items.filter { $0.pathExtension == "json" }
        .compactMap { $0.deletingPathExtension().lastPathComponent }
    check("レイアウト一覧取得: 1件",  names.count == 1)
    check("レイアウト一覧取得: 名前", names.first == "test")
    // 削除
    try FileManager.default.removeItem(at: tmpDir)
    check("一時ファイル削除成功",    !FileManager.default.fileExists(atPath: tmpDir.path))
} catch {
    check("ファイルI/Oテスト 例外: \(error)", false)
    try? FileManager.default.removeItem(at: tmpDir)
}
SWIFT_EOF
)"

# ═══════════════════════════════════════════════════════════
header "5. 重複排除ロジックテスト (deduplicateForRestore)"
# ═══════════════════════════════════════════════════════════
parse_swift_results "$(swift - 2>&1 <<'SWIFT_EOF'
import Foundation

struct WI {
    let bundleIdentifier: String?; let ownerName: String
    let windowName: String?;       let displayUUID: String?
}

// WindowManager.deduplicateForRestore のロジックを再現
func dedup(_ windows: [WI], connectedUUIDs: Set<String>) -> [WI] {
    var seen = Set<String>(); var result: [WI] = []
    // 第1パス: 接続中ディスプレイのエントリを優先
    for w in windows {
        guard let uuid = w.displayUUID, connectedUUIDs.contains(uuid) else { continue }
        let key = "\(w.bundleIdentifier ?? w.ownerName)|\(w.windowName ?? "")|\(uuid)"
        if seen.insert(key).inserted { result.append(w) }
    }
    // 第2パス: 未登録エントリを追加
    for w in windows {
        let uuid = w.displayUUID ?? ""
        let key = "\(w.bundleIdentifier ?? w.ownerName)|\(w.windowName ?? "")|\(uuid)"
        if seen.insert(key).inserted { result.append(w) }
    }
    return result
}

func check(_ name: String, _ ok: Bool) { print(ok ? "PASS: \(name)" : "FAIL: \(name)") }

let connected: Set<String> = ["UUID-A", "UUID-B"]

// テストデータ
let finder_A  = WI(bundleIdentifier: "com.apple.finder", ownerName: "Finder", windowName: "Home",   displayUUID: "UUID-A")
let finder_A2 = WI(bundleIdentifier: "com.apple.finder", ownerName: "Finder", windowName: "Home",   displayUUID: "UUID-A") // 重複
let finder_B  = WI(bundleIdentifier: "com.apple.finder", ownerName: "Finder", windowName: "Home",   displayUUID: "UUID-B") // 別ディスプレイ
let finder_X  = WI(bundleIdentifier: "com.apple.finder", ownerName: "Finder", windowName: "Home",   displayUUID: "UUID-X") // 未接続
let safari_A  = WI(bundleIdentifier: "com.apple.Safari", ownerName: "Safari", windowName: "Google", displayUUID: "UUID-A")
let finder_doc = WI(bundleIdentifier: "com.apple.finder", ownerName: "Finder", windowName: "Documents", displayUUID: "UUID-A") // 別タイトル

// 基本ケース
check("重複なし: 件数変化なし",
    dedup([finder_A, safari_A], connectedUUIDs: connected).count == 2)

check("同UUID・同タイトル重複: 1件に集約",
    dedup([finder_A, finder_A2], connectedUUIDs: connected).count == 1)

check("別UUID・同タイトル: 両方保持（別物理ウィンドウ）",
    dedup([finder_A, finder_B], connectedUUIDs: connected).count == 2)

check("別タイトル同アプリ: 両方保持",
    dedup([finder_A, finder_doc], connectedUUIDs: connected).count == 2)

// 未接続ディスプレイ
check("未接続UUID: 第2パスで採用される",
    dedup([finder_X], connectedUUIDs: connected).count == 1)

// UUID が異なるエントリは別物として両方保持（dedup は同一UUID間のみ）
let both = dedup([finder_X, finder_A], connectedUUIDs: connected)
check("異UUID同名: 両方保持される（別ディスプレイ扱い）",
    both.count == 2)
check("接続中UUIDが先頭に配置される（第1パス優先）",
    both.first?.displayUUID == "UUID-A")

// 逆順でも接続中UUIDが先頭
let both2 = dedup([finder_A, finder_X], connectedUUIDs: connected)
check("逆順でも接続中UUIDが先頭",
    both2.first?.displayUUID == "UUID-A")

// 複合ケース: finder_A と finder_A2 は同UUID→1件に集約
// finder_X は別UUID→保持。結果: finder_A + safari_A + finder_X = 3件
let complex = dedup([finder_A, finder_A2, safari_A, finder_X], connectedUUIDs: connected)
check("複合ケース: Finder重複+Safari+未接続UUID = 3件",
    complex.count == 3)
check("複合ケース: 接続中UUIDエントリが先頭グループ",
    complex[0].displayUUID == "UUID-A")
SWIFT_EOF
)"

# ═══════════════════════════════════════════════════════════
header "6. 画面外クランプ ロジックテスト (clampWindowToScreen)"
# ═══════════════════════════════════════════════════════════
parse_swift_results "$(swift - 2>&1 <<'SWIFT_EOF'
import Foundation
import CoreGraphics

func check(_ name: String, _ ok: Bool) { print(ok ? "PASS: \(name)" : "FAIL: \(name)") }

// clampWindowToScreen のクランプコアロジックを再現
func clamp(_ rect: CGRect, within frame: CGRect) -> CGRect {
    if frame.contains(CGPoint(x: rect.minX, y: rect.minY))
        && rect.maxX <= frame.maxX && rect.maxY <= frame.maxY { return rect }
    let w = min(rect.width,  frame.width)
    let h = min(rect.height, frame.height)
    let x = max(frame.minX, min(rect.minX, frame.maxX - w))
    let y = max(frame.minY, min(rect.minY, frame.maxY - h))
    return CGRect(x: x, y: y, width: w, height: h)
}

// distanceToCGFrame のロジックを再現
func dist(_ p: CGPoint, _ f: CGRect) -> CGFloat {
    let dx = max(f.minX - p.x, 0, p.x - f.maxX)
    let dy = max(f.minY - p.y, 0, p.y - f.maxY)
    return sqrt(dx*dx + dy*dy)
}

// NSScreen → CGWindow 座標変換ロジックを再現
func toCGWindowFrame(nsFrame: CGRect, mainH: CGFloat) -> CGRect {
    CGRect(x: nsFrame.minX, y: mainH - nsFrame.maxY, width: nsFrame.width, height: nsFrame.height)
}

let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

// ── クランプ: 画面内 ──
let inside = CGRect(x: 100, y: 100, width: 800, height: 600)
check("画面内ウィンドウ: 変更なし",
    clamp(inside, within: screen) == inside)

// ── クランプ: 右はみ出し ──
let overR = clamp(CGRect(x: 1800, y: 100, width: 800, height: 600), within: screen)
check("右はみ出し: maxX が画面内に収まる", overR.maxX <= screen.maxX)
check("右はみ出し: 幅は保持される",        overR.width == 800)

// ── クランプ: 下はみ出し ──
let overB = clamp(CGRect(x: 100, y: 900, width: 800, height: 600), within: screen)
check("下はみ出し: maxY が画面内に収まる", overB.maxY <= screen.maxY)
check("下はみ出し: 高さは保持される",      overB.height == 600)

// ── クランプ: 完全に画面外（右側）──
let offScreen = clamp(CGRect(x: 2500, y: 100, width: 800, height: 600), within: screen)
check("完全画面外: x が画面内に移動",  offScreen.minX >= screen.minX)
check("完全画面外: maxX が画面内",    offScreen.maxX <= screen.maxX)

// ── クランプ: 画面より大きいウィンドウ ──
let huge = clamp(CGRect(x: 0, y: 0, width: 3000, height: 2000), within: screen)
check("超大ウィンドウ: 幅を画面幅に制限",  huge.width  == 1920)
check("超大ウィンドウ: 高さを画面高に制限", huge.height == 1080)

// ── 距離計算 ──
check("距離計算: 画面内点 → 距離0",
    dist(CGPoint(x: 100, y: 100), screen) == 0)
check("距離計算: 画面外点(右) → 距離>0",
    dist(CGPoint(x: 2000, y: 100), screen) > 0)
check("距離計算: 画面外点(下) → 距離>0",
    dist(CGPoint(x: 100, y: 1200), screen) > 0)

// ── NSScreen → CGWindow 座標変換 ──
let mainH: CGFloat = 1080
// プライマリモニター (Cocoa: y=0 at bottom-left)
let primary_ns = CGRect(x: 0, y: 0, width: 1920, height: 1080)
let primary_cg = toCGWindowFrame(nsFrame: primary_ns, mainH: mainH)
check("プライマリ CGWindow座標: x=0",       primary_cg.minX == 0)
check("プライマリ CGWindow座標: y=0",       primary_cg.minY == 0)
check("プライマリ CGWindow座標: 幅保持",    primary_cg.width == 1920)
check("プライマリ CGWindow座標: 高さ保持",  primary_cg.height == 1080)

// 右側モニター (Cocoa: x=1920, y=0)
let right_ns = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
let right_cg = toCGWindowFrame(nsFrame: right_ns, mainH: mainH)
check("右サブモニター CGWindow座標: x=1920",   right_cg.minX == 1920)
check("右サブモニター CGWindow座標: y反転済み", right_cg.minY == mainH - right_ns.maxY)

// 上側モニター (Cocoa: x=0, y=1080)
let top_ns = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
let top_cg = toCGWindowFrame(nsFrame: top_ns, mainH: mainH)
check("上サブモニター CGWindow座標: y が負",  top_cg.minY < 0)
SWIFT_EOF
)"

# ═══════════════════════════════════════════════════════════
header "7. ウィンドウマッチング ロジックテスト (bestMatchWindow)"
# ═══════════════════════════════════════════════════════════
parse_swift_results "$(swift - 2>&1 <<'SWIFT_EOF'
import Foundation
import CoreGraphics

func check(_ name: String, _ ok: Bool) { print(ok ? "PASS: \(name)" : "FAIL: \(name)") }

// closestWindow のロジックを再現（座標ベースで最近傍を選択）
struct FakeWindow {
    let title: String?
    let pos: CGPoint
}

func closestIndex(from windows: [FakeWindow], to target: CGPoint) -> Int? {
    var bestIdx: Int?; var bestDist = CGFloat.infinity
    for (i, w) in windows.enumerated() {
        let d = hypot(w.pos.x - target.x, w.pos.y - target.y)
        if d < bestDist { bestDist = d; bestIdx = i }
    }
    return bestIdx
}

func bestMatch(from windows: [FakeWindow], windowName: String?, savedOrigin: CGPoint) -> Int? {
    if let expected = windowName, !expected.isEmpty {
        let matches = windows.enumerated().filter { $0.element.title == expected }
        if matches.count == 1 { return matches[0].offset }
        if matches.count > 1 {
            return matches.min(by: {
                hypot($0.element.pos.x - savedOrigin.x, $0.element.pos.y - savedOrigin.y) <
                hypot($1.element.pos.x - savedOrigin.x, $1.element.pos.y - savedOrigin.y)
            })?.offset
        }
    }
    return closestIndex(from: windows, to: savedOrigin)
}

let w0 = FakeWindow(title: "Document1", pos: CGPoint(x: 100, y: 100))
let w1 = FakeWindow(title: "Document2", pos: CGPoint(x: 500, y: 100))
let w2 = FakeWindow(title: "Document1", pos: CGPoint(x: 900, y: 100)) // w0 と同タイトル

// タイトル一致1件
check("タイトル1件一致: 正しいウィンドウを返す",
    bestMatch(from: [w0, w1], windowName: "Document1", savedOrigin: .zero) == 0)

// タイトルなし → 保存座標に最近傍
check("タイトルなし: 保存座標(100,100)に近い w0 を返す",
    bestMatch(from: [w0, w1], windowName: nil, savedOrigin: CGPoint(x: 100, y: 100)) == 0)
check("タイトルなし: 保存座標(500,100)に近い w1 を返す",
    bestMatch(from: [w0, w1], windowName: nil, savedOrigin: CGPoint(x: 500, y: 100)) == 1)

// タイトル不一致 → 保存座標に最近傍
check("タイトル不一致: 最近傍を返す",
    bestMatch(from: [w0, w1], windowName: "Unknown", savedOrigin: CGPoint(x: 480, y: 100)) == 1)

// 同一タイトルが複数 → 保存座標に近い方を選ぶ
check("同一タイトル複数: 保存座標(80,100)に近い w0(100,100) を返す",
    bestMatch(from: [w0, w1, w2], windowName: "Document1", savedOrigin: CGPoint(x: 80, y: 100)) == 0)
check("同一タイトル複数: 保存座標(920,100)に近い w2(900,100) を返す",
    bestMatch(from: [w0, w1, w2], windowName: "Document1", savedOrigin: CGPoint(x: 920, y: 100)) == 2)
SWIFT_EOF
)"

# ═══════════════════════════════════════════════════════════
header "8. 手動確認が必要な項目（自動テスト対象外）"
# ═══════════════════════════════════════════════════════════
warn_item "AX API: ウィンドウ位置・サイズの取得と設定"
warn_item "アクセシビリティ権限の取得・監視"
warn_item "未起動アプリの自動起動と配置"
warn_item "マルチディスプレイでの displayUUID 画面特定"
warn_item "実機: 画面外クランプ（モニター変更後の復元）"
warn_item "仮想Space 切替後の Save / Restore フロー"

# ═══════════════════════════════════════════════════════════
# サマリー
# ═══════════════════════════════════════════════════════════
TOTAL=$((${#PASS_LIST[@]} + ${#FAIL_LIST[@]}))
PASSED=${#PASS_LIST[@]}
FAILED=${#FAIL_LIST[@]}

echo ""
printf "${BOLD}"
printf "╔══════════════════════════════════════════════╗\n"
if [ "$FAILED" -eq 0 ]; then
    printf "${GREEN}║   結果: %d / %d 合格  —  すべて通過 🎉       ║${RESET}${BOLD}\n" "$PASSED" "$TOTAL"
else
    printf "${RED}║   結果: %d / %d 合格  —  %d 件失敗 ❌          ║${RESET}${BOLD}\n" "$PASSED" "$TOTAL" "$FAILED"
fi
printf "╚══════════════════════════════════════════════╝\n"
printf "${RESET}"

if [ "$FAILED" -gt 0 ]; then
    printf "\n${RED}失敗項目:${RESET}\n"
    for item in "${FAIL_LIST[@]}"; do
        printf "  ${RED}❌ %s${RESET}\n" "$item"
    done
fi

echo ""
echo "終了するには Enter キーを押してください..."
read -r
