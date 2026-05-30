// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DriftSonarCore",
    platforms: [
        .macOS(.v14), .iOS(.v17)
    ],
    products: [
        .library(
            name: "DriftSonarCore",
            targets: ["DriftSonarCore"]
        ),
    ],
    dependencies: [
        // TASK-043: SwiftLint as a build tool plugin for consistent code style.
        .package(url: "https://github.com/realm/SwiftLint", from: "0.57.0"),
    ],
    targets: [
        .target(
            name: "DriftSonarCore",
            plugins: [
                // TASK-043: Run SwiftLint on every build.
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint"),
            ]
        ),
        .testTarget(
            name: "DriftSonarCoreTests",
            dependencies: ["DriftSonarCore"]
        ),
    ]
)
