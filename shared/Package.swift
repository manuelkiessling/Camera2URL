// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Camera2URLShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Camera2URLShared",
            targets: ["Camera2URLShared"]),
    ],
    targets: [
        .target(
            name: "Camera2URLShared"),
        .testTarget(
            name: "Camera2URLSharedTests",
            dependencies: ["Camera2URLShared"]),
    ]
)

