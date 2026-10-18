// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "IdtraKYC",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "IdtraKYC",
            targets: ["IdtraKYC"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IdtraKYC",
            dependencies: [],
            path: "Sources/IdtraKYC"
        ),
    ]
)
