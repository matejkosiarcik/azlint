// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "matejkosiarcik-azlint-swift",
    products: [
    ],
    dependencies: [
        .package(url: "https://github.com/yonaskolb/Mint.git", .upToNextMinor(from: "0.14.2")),
        // .package(url: "https://github.com/realm/SwiftLint.git", .upToNextMinor(from: "0.39.2")),
    ],
    targets: [
        // Must have at least 1 target, otherwise swift refuses to install dependencies and build project
        .target(name: "placeholder", dependencies: []),
    ]
)
