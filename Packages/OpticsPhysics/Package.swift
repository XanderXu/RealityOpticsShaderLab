// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "OpticsPhysics",
    platforms: [
        .visionOS(.v2),
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OpticsPhysics",
            targets: ["OpticsPhysics"]),
    ],
    targets: [
        .target(
            name: "OpticsPhysics",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]),
        .testTarget(
            name: "OpticsPhysicsTests",
            dependencies: ["OpticsPhysics"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]),
    ]
)
