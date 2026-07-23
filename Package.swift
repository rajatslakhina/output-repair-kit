// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OutputRepairKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "OutputRepairKit", targets: ["OutputRepairKit"]),
        .executable(name: "OutputRepairDemo", targets: ["OutputRepairDemo"])
    ],
    targets: [
        .target(
            name: "OutputRepairKit"
        ),
        .executableTarget(
            name: "OutputRepairDemo",
            dependencies: ["OutputRepairKit"]
        ),
        .testTarget(
            name: "OutputRepairKitTests",
            dependencies: ["OutputRepairKit"]
        )
    ]
)
