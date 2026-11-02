// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ContourLabKit",
    platforms: [.iOS("27.0"), .macOS("27.0")],
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
