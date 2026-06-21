// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "NanoPlayer",
    platforms: [.macOS(.v12)],
    targets: [
        // libmpv (Homebrew) exposed via pkg-config — no hardcoded paths.
        .systemLibrary(
            name: "Cmpv",
            path: "Sources/Cmpv",
            pkgConfig: "mpv",
            providers: [.brew(["mpv"])]
        ),
        .executableTarget(
            name: "NanoPlayer",
            dependencies: ["Cmpv"],
            path: "Sources/NanoPlayer"
        ),
    ]
)
