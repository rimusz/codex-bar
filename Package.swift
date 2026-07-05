// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "CodexBar",
            targets: ["CodexBar"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CodexBar",
            path: "CodexBar",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CodexBarTests",
            dependencies: ["CodexBar"]
        )
    ]
)
