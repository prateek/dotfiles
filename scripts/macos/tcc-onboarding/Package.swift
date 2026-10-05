// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DotfilesPermissions",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DotfilesPermissions", targets: ["PermissionsApp"])],
    targets: [
        .target(name: "PermissionsCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "PermissionsApp", dependencies: ["PermissionsCore"]),
        .testTarget(name: "PermissionsCoreTests", dependencies: ["PermissionsCore"]),
    ],
    swiftLanguageModes: [.v5]
)
