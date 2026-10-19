// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "maxguspicker1824",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "maxguspicker1824", targets: ["maxguspicker1824"])
    ],
    targets: [
        .executableTarget(
            name: "maxguspicker1824",
            path: "Sources/maxguspicker1824"
        ),
        .testTarget(
            name: "maxguspicker1824Tests",
            dependencies: ["maxguspicker1824"],
            path: "Tests/maxguspicker1824Tests"
        )
    ]
)
