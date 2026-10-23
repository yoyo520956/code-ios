// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Code",
    platforms: [
        .iOS(.v17)
    ],
    targets: [
        .executableTarget(
            name: "Code",
            dependencies: [],
            path: "Sources"
        )
    ]
)
