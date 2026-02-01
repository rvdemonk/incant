// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Incant",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Incant",
            path: "Sources/Incant"
        )
    ]
)
