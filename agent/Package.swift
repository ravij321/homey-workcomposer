// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HomeyAgent",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "HomeyAgent", targets: ["HomeyAgent"])
    ],
    targets: [
        .executableTarget(name: "HomeyAgent")
    ]
)
