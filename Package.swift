// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DockDrop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DockDrop",
            targets: ["DockDrop"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DockDrop",
            path: "Sources/DockDrop",
            exclude: [
                "App/Info.plist",
                "Resources/README.md"
            ]
        )
    ]
)
