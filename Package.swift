// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Frameless",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Frameless")
    ]
)
