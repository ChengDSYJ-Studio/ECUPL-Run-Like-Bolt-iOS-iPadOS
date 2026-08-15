// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ECUPLLocationController",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ECUPLLocationController", targets: ["ECUPLLocationController"])
    ],
    targets: [
        .executableTarget(name: "ECUPLLocationController")
    ]
)
