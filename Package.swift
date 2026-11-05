// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WalkunoCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "WalkunoCore", targets: ["WalkunoCore"])],
    targets: [
        .target(name: "WalkunoCore"),
        .testTarget(name: "WalkunoCoreTests", dependencies: ["WalkunoCore"])
    ]
)
