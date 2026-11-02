// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContourLabKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ContourLabKit", targets: ["ContourLabKit"])
    ],
    targets: [
        .target(name: "ContourLabKit"),
        .testTarget(
            name: "ContourLabKitTests",
            dependencies: ["ContourLabKit"],
            resources: [.copy("Resources")]
        )
    ]
)
