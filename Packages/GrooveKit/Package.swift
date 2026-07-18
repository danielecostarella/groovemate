// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GrooveKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "GrooveModel", targets: ["GrooveModel"]),
        .library(name: "GrooveBrain", targets: ["GrooveBrain"]),
        .library(name: "GrooveEngine", targets: ["GrooveEngine"]),
    ],
    targets: [
        .target(name: "GrooveModel"),
        .executableTarget(
            name: "groovemate-render",
            dependencies: ["GrooveModel", "GrooveBrain", "GrooveEngine"]
        ),
        .target(name: "GrooveBrain", dependencies: ["GrooveModel"]),
        .target(name: "GrooveEngine", dependencies: ["GrooveModel"]),
        .testTarget(name: "GrooveBrainTests", dependencies: ["GrooveBrain"]),
        .testTarget(name: "GrooveEngineTests", dependencies: ["GrooveEngine", "GrooveBrain"]),
    ]
)
