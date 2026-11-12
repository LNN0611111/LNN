// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BenchmarkAnimator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BenchmarkCore", targets: ["BenchmarkCore"]),
        .executable(name: "BenchmarkAnimator", targets: ["BenchmarkAnimator"])
    ],
    targets: [
        .target(
            name: "BenchmarkCore"
        ),
        .executableTarget(
            name: "BenchmarkAnimator",
            dependencies: ["BenchmarkCore"]
        )
    ]
)
