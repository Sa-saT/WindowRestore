// swift-tools-version:5.3
// Swift Package Managerマニフェスト
// macOSアプリのビルド設定を定義

import PackageDescription

let package = Package(
    name: "mac-app",  // パッケージ名
    platforms: [
        .macOS(.v10_15)  // macOS 10.15 (Catalina) 以降をサポート
    ],
    products: [
        // 実行可能ファイルとしてビルド
        .executable(name: "mac-app", targets: ["mac-app"]),
    ],
    dependencies: [],  // 外部依存なし
    targets: [
        .target(
            name: "mac-app",
            dependencies: [],  // ターゲット依存なし
            path: "Sources",   // ソースコードのパス
            sources: ["mac-app/main.swift"],  // ビルドするソースファイル
            cSettings: [
                // Cコンパイラ設定: Rustライブラリのヘッダーとライブラリパスを指定
                .unsafeFlags(["-I../../", "-L../../target/release/", "-I./Bridging/"])
            ],
            linkerSettings: [
                // リンカー設定: Rustライブラリ（libwindow_restore）とリンク
                .linkedLibrary("window_restore")
            ]
        )
    ]
)
