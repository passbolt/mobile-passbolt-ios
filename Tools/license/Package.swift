// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "license",
  dependencies: [
    .package(
      name: "LicensePlist",
      url: "https://github.com/mono0926/LicensePlist.git", .upToNextMajor(from: "3.23.4")
    ),
  ],
  targets: [
    .target(
      name: "license",
      dependencies: [
        .product(name: "license-plist", package: "LicensePlist")
      ]
    ),
  ]
)
