// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Code",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Code",
            targets: ["Code"]
        ),
    ],
    targets: [
        .target(
            name: "Code",
            dependencies: [],
            path: "Sources",
            exclude: [
                "main.swift"
            ]
        )
    ]
)
