// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WaveyEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v13), // so `swift test` runs on the host Mac without a simulator
    ],
    products: [
        .library(name: "WaveyEngine", targets: ["WaveyEngine"]),
    ],
    targets: [
        .target(name: "WaveyEngine"),
        .testTarget(
            name: "WaveyEngineTests",
            dependencies: ["WaveyEngine"],
            resources: [.copy("Resources")]
        ),
    ],
    // Swift 5 mode for now — revisit Swift 6 strict concurrency once the
    // realtime-audio modules (M1–M2) exist and we can migrate deliberately.
    swiftLanguageModes: [.v5]
)
