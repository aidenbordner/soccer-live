// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoccerKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SoccerModels", targets: ["SoccerModels"]),
        .library(name: "SoccerBackend", targets: ["SoccerBackend"]),
        .library(name: "ScoreboardUI", targets: ["ScoreboardUI"]),
    ],
    targets: [
        .target(name: "SoccerModels"),
        .target(name: "SoccerBackend", dependencies: ["SoccerModels"]),
        .target(name: "ScoreboardUI", dependencies: ["SoccerModels"]),
        .testTarget(name: "SoccerModelsTests", dependencies: ["SoccerModels"]),
        .testTarget(name: "SoccerBackendTests", dependencies: ["SoccerBackend"]),
    ]
)
