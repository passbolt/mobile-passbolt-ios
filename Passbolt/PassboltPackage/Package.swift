// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "PassboltPackage",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "Accounts",
      targets: ["Accounts"]
    ),
    .library(
      name: "AccountSetup",
      targets: ["AccountSetup"]
    ),
    .library(
      name: "CommonUI",
      targets: ["CommonUI"]
    ),
    .library(
      name: "Crypto",
      targets: ["Crypto"]
    ),
    .library(
      name: "Networking",
      targets: ["Networking"]
    ),
    .library(
      name: "NetworkClient",
      targets: ["NetworkClient"]
    ),
    .library(
      name: "PassboltApp",
      targets: ["PassboltApp"]
    ),
    .library(
      name: "PassboltExtension",
      targets: ["PassboltExtension"]
    ),
    .library(
      name: "Resources",
      targets: ["Resources"]
    ),
    .library(
      name: "Safety",
      targets: ["Safety"]
    ),
    .library(
      name: "Settings",
      targets: ["Settings"]
    ),
    .library(
      name: "SignIn",
      targets: ["SignIn"]
    ),
    .library(
      name: "Storage",
      targets: ["Storage"]
    ),
    .library(
      name: "User",
      targets: ["User"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "Accounts",
      dependencies: [
        "Settings",
        "Storage"
      ]
    ),
    .target(
      name: "AccountSetup",
      dependencies: [
        "Accounts",
        "NetworkClient",
        "Safety"
      ]
    ),
    .target(name: "CommonUI"),
    .target(
      name: "Crypto",
      dependencies: [] // TODO: Add opengpg as dependency
    ),
    .target(name: "Networking"),
    .target(
      name: "NetworkClient",
      dependencies: [
        "Accounts",
        "Networking"
      ]
    ),
    .target(
      name: "PassboltApp",
      dependencies: [
        "Accounts",
        "AccountSetup",
        "CommonUI",
        "SignIn",
        "Resources",
        "User"
      ]
    ),
    .testTarget(
      name: "PassboltAppTests",
      dependencies: ["PassboltApp"]
    ),
    .target(
      name: "PassboltExtension",
      dependencies: []
    ),
    .testTarget(
      name: "PassboltExtensionTests",
      dependencies: ["PassboltExtension"]
    ),
    .target(
      name: "Resources",
      dependencies: [
        "Accounts",
        "NetworkClient",
        "Safety",
        "Settings",
        "Storage"
      ]
    ),
    .target(
      name: "Safety",
      dependencies: [
        "Accounts",
        "Crypto",
        "Settings"
      ]
    ),
    .target(
      name: "Settings",
      dependencies: ["Storage"]
    ),
    .target(
      name: "SignIn",
      dependencies: [
        "Accounts",
        "Safety",
        "NetworkClient"
      ]
    ),
    .target(
      name: "Storage",
      dependencies: [] // TODO: Add database as dependency
    ),
    .target(
      name: "User",
      dependencies: [
        "Accounts",
        "NetworkClient",
        "Safety",
        "Settings",
        "Storage"
      ]
    )
  ]
)
