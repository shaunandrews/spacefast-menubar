// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SpacefastMenubar",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "SpacefastMenubar",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/SpacefastMenubar",
            // build.sh copies Sparkle.framework into Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ],
    swiftLanguageModes: [.v5]
)
