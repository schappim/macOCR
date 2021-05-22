// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "macOCR",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(name: "swift-argument-parser",
                 url: "https://github.com/apple/swift-argument-parser.git",
                 .exact("0.3.1")),
    ],
    targets: [
        .target(name: "ocr",
                dependencies: [
                    .product(name: "ArgumentParser",
                             package: "swift-argument-parser"),
        ]),
    ]
)
