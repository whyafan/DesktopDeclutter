// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopDeclutter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DesktopDeclutter", targets: ["DesktopDeclutter"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DesktopDeclutter",
            dependencies: [],
            path: "Sources/DesktopDeclutter"
        )
    ]
)
