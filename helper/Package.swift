// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenContext",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ScreenContextCore"),
        .executableTarget(name: "ScreenContext", dependencies: ["ScreenContextCore"]),
        .testTarget(name: "ScreenContextCoreTests", dependencies: ["ScreenContextCore"]),
    ]
)
