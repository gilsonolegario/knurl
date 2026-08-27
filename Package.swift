// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Knurl",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KnurlCore", targets: ["KnurlCore"]),
        .executable(name: "Knurl", targets: ["Knurl"])
    ],
    targets: [
        .target(name: "KnurlCore"),
        .executableTarget(
            name: "Knurl",
            dependencies: ["KnurlCore"],
            resources: [.copy("Resources/Icon.png")]
        ),
        .testTarget(name: "KnurlCoreTests", dependencies: ["KnurlCore"]),
        .testTarget(name: "KnurlTests", dependencies: ["Knurl"])
    ]
)
