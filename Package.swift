// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SpacefastMenubar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "SpacefastMenubar", path: "Sources/SpacefastMenubar")
    ],
    swiftLanguageModes: [.v5]
)
