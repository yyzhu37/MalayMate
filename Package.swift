// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MalayMate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MalayMateCore", targets: ["MalayMateCore"]),
        .executable(name: "MalayMate", targets: ["MalayMate"])
    ],
    targets: [
        .target(
            name: "MalayMateCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "MalayMate",
            dependencies: ["MalayMateCore"]
        ),
        .testTarget(
            name: "MalayMateCoreTests",
            dependencies: ["MalayMateCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
