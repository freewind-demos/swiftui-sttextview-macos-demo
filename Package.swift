// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swiftui-sttextview-macos-demo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/STTextView", from: "2.3.10"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        .executableTarget(
            name: "swiftui-sttextview-macos-demo",
            dependencies: [
                .product(name: "STTextView", package: "STTextView"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
    ]
)
