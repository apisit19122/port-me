// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PortMe",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PortMeKit"),
        .executableTarget(name: "PortMe", dependencies: ["PortMeKit"]),
        .testTarget(name: "PortMeTests", dependencies: ["PortMeKit"]),
    ]
)
