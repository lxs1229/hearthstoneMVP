// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HearthstoneMVP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HearthstoneMVP", targets: ["HearthstoneMVP"])
    ],
    targets: [
        .executableTarget(
            name: "HearthstoneMVP",
            path: "Sources/HearthstoneMVP"
        )
    ]
)
