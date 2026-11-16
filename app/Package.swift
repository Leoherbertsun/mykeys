// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MyKeys",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MyKeys", path: "Sources/MyKeys")
    ]
)
