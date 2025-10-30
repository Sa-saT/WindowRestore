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
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            linkerSettings: []
        )
    ]
)
