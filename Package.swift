// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FitCat",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FitCat",
            targets: ["FitCat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "FitCat",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "FitCat"),
        .testTarget(
            name: "FitCatTests",
            dependencies: ["FitCat"],
            path: "FitCatTests"),
    ]
)
