// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SteadyKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SteadyKit", targets: ["SteadyKit"]),
    ],
    targets: [
        .target(
            name: "SteadyKit",
            resources: [
                .process("Resources/places.json"),
                .process("Resources/landmarks.json"),
                .copy("Resources/journeys"),
            ]
        ),
        .testTarget(
            name: "SteadyKitTests",
            dependencies: ["SteadyKit"]
        ),
    ]
)
