// swift-tools-version:5.9
// Build: apps/macos/build.sh (builds the Rust staticlib first, then `swift build`). No signing needed.
import PackageDescription

let package = Package(
    name: "OpenKef",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "COpenKef", path: "Sources/COpenKef",
                linkerSettings: [.linkedLibrary("openkef_ffi")]),
        .executableTarget(name: "OpenKef", dependencies: ["COpenKef"], path: "Sources/OpenKef"),
    ]
)
