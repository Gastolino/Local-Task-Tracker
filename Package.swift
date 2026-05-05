// swift-tools-version: 5.9
import PackageDescription

// Open this file in Xcode (File → Open → Package.swift) to build the app.
// See README for how to add the entitlements and code signing.
let package = Package(
    name: "LocalTaskTracker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LocalTaskTracker",
            path: "Sources/LocalTaskTracker",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
