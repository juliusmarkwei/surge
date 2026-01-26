// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SURGE",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SURGE", targets: ["SURGE"]),
        .executable(name: "PrivilegedHelper", targets: ["PrivilegedHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SURGE",
            dependencies: [
                "Shared",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/SURGE"
        ),
        .executableTarget(
            name: "PrivilegedHelper",
            dependencies: [
                "Shared",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/PrivilegedHelper"
        ),
        .target(
            name: "Shared",
            dependencies: [],
            path: "Sources/Shared"
        ),
        .testTarget(
            name: "SURGETests",
            dependencies: ["SURGE", "Shared"],
            path: "Tests/SURGETests"
        ),
        .testTarget(
            name: "PrivilegedHelperTests",
            dependencies: ["PrivilegedHelper", "Shared"],
            path: "Tests/PrivilegedHelperTests"
        )
    ]
)
