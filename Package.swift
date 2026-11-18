// swift-tools-version: 6.0
import PackageDescription
import Foundation

// CMake owns the existing C++ protocol/transport libraries. This package provides
// Swift editor/build-system context and an alternate executable build after
// `bash macos/build.sh` has produced those libraries. It is not an app bundler.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let package = Package(
    name: "ProjectXMConnect",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "ProjectXMConnect", targets: ["ProjectXMConnect"])],
    targets: [
        .systemLibrary(name: "XMConnectBridge", path: "macos/Bridge"),
        .executableTarget(
            name: "ProjectXMConnect",
            dependencies: ["XMConnectBridge"],
            path: "macos/Sources",
            swiftSettings: [.unsafeFlags([
                "-Xcc", "-I\(root)/libmdr/include",
                "-Xcc", "-I\(root)/libmdr-bt/include"
            ])],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(root)/build-native/libmdr/src", "-lmdr",
                    "-L\(root)/build-native/libmdr-bt/src", "-lmdr-bt"
                ]),
                .linkedLibrary("c++"), .linkedFramework("Foundation"),
                .linkedFramework("IOBluetooth"), .linkedFramework("AppKit")
            ]
        )
    ]
)
