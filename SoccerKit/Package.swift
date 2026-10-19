// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoccerKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SoccerModels", targets: ["SoccerModels"]),
    ],
    targets: [
        .target(name: "SoccerModels"),
        .testTarget(name: "SoccerModelsTests", dependencies: ["SoccerModels"]),
    ]
)
