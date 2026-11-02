// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Stash",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Stash",
            // build.sh copies Sparkle.framework into Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ],
    swiftLanguageModes: [.v5]
)
