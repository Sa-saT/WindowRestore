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
        .executableTarget(
            name: "mac-app",
            path: "Sources/mac-app",
            resources: [],
            cSettings: [
                .headerSearchPath("../Bridging")
            ],
            linkerSettings: [
                .unsafeFlags(["-L", "../target/debug", "-L", "../target/release"], .when(platforms: [.macOS])),
                .linkedLibrary("window_restore")
            ]
        )
    ]
)
