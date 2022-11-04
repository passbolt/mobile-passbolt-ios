// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
// swift-format as a Swift Package
// Run by issuing the following from the command prompt:
// swift run swift-format

import PackageDescription

let package = Package(
  name: "format",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(
      name: "swift-format",
      url: "https://github.com/apple/swift-format.git", .exact("0.50700.1")
    )
  ],
  targets: [
    .target(
      name: "format",
      dependencies: [.product(name: "swift-format", package: "swift-format")])
  ]
)
