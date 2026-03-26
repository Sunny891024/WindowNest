// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WindowNest",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "WindowNest"
        ),
    ]
)
