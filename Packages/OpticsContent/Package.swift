// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "OpticsContent",
    platforms: [
        .visionOS(.v2),
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "OpticsContent",
            targets: ["OpticsContent"]),
    ],
    targets: [
        .target(
            name: "OpticsContent",
            dependencies: [],
            resources: [
                .copy("Materials")
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]),
    ]
)
