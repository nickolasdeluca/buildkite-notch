// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuildkiteNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BuildkiteNotchCore"),
        .executableTarget(
            name: "BuildkiteNotch",
            dependencies: ["BuildkiteNotchCore"]
        ),
        .testTarget(
            name: "BuildkiteNotchCoreTests",
            dependencies: ["BuildkiteNotchCore"]
        ),
    ]
)
