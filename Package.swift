// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SeggWatSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SeggWatSDK",
            targets: ["SeggWatSDK"]
        ),
    ],
    targets: [
        .target(
            name: "SeggWatSDK",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SeggWatSDKTests",
            dependencies: ["SeggWatSDK"]
        ),
    ]
)
