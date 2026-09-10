// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MowEngine",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "MowEngine", targets: ["MowEngine"])
    ],
    targets: [
        .target(name: "MowEngine"),
        .testTarget(name: "MowEngineTests", dependencies: ["MowEngine"])
    ]
)
