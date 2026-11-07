// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Talk2Mac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Talk2Mac", path: "Sources/Talk2Mac")
    ]
)
