// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CodexPace", platforms: [.macOS(.v14)], products: [.executable(name: "CodexPace", targets: ["CodexPace"])], targets: [
    .target(name: "PaceCore"),
    .executableTarget(name: "CodexPace", dependencies: ["PaceCore"]),
    .testTarget(name: "PaceCoreTests", dependencies: ["PaceCore"])
])
