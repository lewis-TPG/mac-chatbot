// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OllamaChat",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OllamaChat", targets: ["OllamaChat"]),
    ],
    dependencies: [
        // Add any dependencies you want
    ],
    targets: [
        .target(
            name: "OllamaChat",
            dependencies: []
        ),
    ]
)