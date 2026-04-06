// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClarityBuds",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClarityBuds",
            path: "ClarityBuds",
            exclude: [
                "Info.plist",
                "ClarityBuds.entitlements"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
