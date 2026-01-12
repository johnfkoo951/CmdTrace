// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CmdTrace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CmdTrace", targets: ["CmdTrace"])
    ],
    targets: [
        .executableTarget(
            name: "CmdTrace",
            path: "Sources"
        )
    ]
)
