// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StoryStamper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StoryStamper",
            path: "Sources/StoryStamper"
        )
    ]
)
