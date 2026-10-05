// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenContext",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ScreenContextCore"),
        .executableTarget(
            name: "ScreenContext",
            dependencies: ["ScreenContextCore"],
            // AppKit callbacks run on the main thread; Swift 6 checking would only add ceremony here.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "ScreenContextCoreTests", dependencies: ["ScreenContextCore"]),
    ]
)
