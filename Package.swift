// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cairn",
    platforms: [.macOS("14.0"), .iOS("17.0")],
    targets: [
        .executableTarget(name: "Cairn", path: "Sources/Cairn")
    ]
)
