// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Elvis",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ElvisKit"),
        .executableTarget(
            name: "elvis",
            dependencies: ["ElvisKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "ElvisKitTests", dependencies: ["ElvisKit"]),
        .testTarget(name: "ElvisAppTests", dependencies: ["elvis"]),
    ]
)
