// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
// SwiftLint as a Swift Package
// Run by issuing the following from the command prompt:
// swift run swiftlint
import PackageDescription

let package = Package(
  name: "lint",
  platforms: [.macOS(.v10_12)],
  dependencies: [
    .package(
      name: "SwiftLint",
      url: "https://github.com/realm/SwiftLint.git", .branch("master")
    )
  ],
  targets: [
    .target(
      name: "lint",
      dependencies: [.product(name: "swiftlint", package: "SwiftLint")])
  ]
)
