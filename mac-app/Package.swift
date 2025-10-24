// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mac-app",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mac-app", targets: ["mac-app"]) 
    ],
    targets: [
        // Clangモジュール: Rustで生成したヘッダー/モジュールマップをSwiftからimport可能にする
        .target(
            name: "window_restore",
            path: "Bridging",
            publicHeadersPath: "."
        ),
        .executableTarget(
            name: "mac-app",
            dependencies: ["window_restore"],
            path: "Sources",
            resources: [],
            linkerSettings: [
                .unsafeFlags(["-L", "../target/debug", "-L", "../target/release"], .when(platforms: [.macOS])),
                .linkedLibrary("window_restore")
            ]
        )
    ]
)
