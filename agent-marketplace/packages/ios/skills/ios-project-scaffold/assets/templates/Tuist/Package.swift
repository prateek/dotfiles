// swift-tools-version: 5.9
// ABOUTME: Declares external Swift package dependencies for Tuist to resolve.
// ABOUTME: Run `tuist install` after editing this file.

import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

let package = Package(
    name: "__APP_NAME__",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.18.6"),
    ]
)
