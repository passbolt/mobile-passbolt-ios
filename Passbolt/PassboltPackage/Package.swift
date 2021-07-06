// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "PassboltPackage",
  defaultLocalization: "en",
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
      name: "Commons",
      targets: ["Commons"]
    ),
    .library(
      name: "Crypto",
      targets: ["Crypto"]
    ),
    .library(
      name: "Features",
      targets: ["Features"]
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
      name: "Settings",
      targets: ["Settings"]
    ),
    .library(
      name: "UICommons",
      targets: ["UICommons"]
    ),
    .library(
      name: "UIComponents",
      targets: ["UIComponents"]
    ),
    .library(
      name: "Environment",
      targets: [
        "Environment"
      ]
    ),
  ],
  dependencies: [
    .package(
      name: "Aegithalos",
      url: "https://github.com/miquido/aegithalos.git",
      .upToNextMajor(from: "2.2.0")
    )
  ],
  targets: [
    .target(
      name: "Accounts",
      dependencies: [
        "Commons",
        "Crypto",
        "Features",
        "NetworkClient",
        "Settings",
      ]
    ),
    .testTarget(
      name: "AccountsTests",
      dependencies: [
        "Accounts",
        "TestExtensions",
      ]
    ),
    .target(
      name: "AccountSetup",
      dependencies: [
        "Accounts",
        "Commons",
        "Crypto",
        "Features",
        "NetworkClient",
      ]
    ),
    .testTarget(
      name: "AccountSetupTests",
      dependencies: [
        "AccountSetup",
        "TestExtensions",
      ]
    ),
    .target(
      name: "Commons",
      dependencies: [
        .product(name: "AegithalosCocoa", package: "Aegithalos")
      ],
      resources: [
        .process("Localizable.strings")
      ]
    ),
    .testTarget(
      name: "CommonsTests",
      dependencies: [
        "Commons",
        "TestExtensions",
      ]
    ),
    .target(
      name: "Crypto",
      dependencies: [
        "Commons",
        "gopenPGP",
      ]
    ),
    .testTarget(
      name: "CryptoTests",
      dependencies: [
        "Commons",
        "Crypto",
        "TestExtensions",
      ]
    ),
    .target(
      name: "Features",
      dependencies: [
        "Commons",
        "Environment",
      ]
    ),
    .testTarget(
      name: "FeaturesTests",
      dependencies: [
        "Features",
        "TestExtensions",
      ]
    ),
    .target(
      name: "NetworkClient",
      dependencies: [
        "Commons",
        "Crypto",
        "Features",
        "Environment",
      ]
    ),
    .testTarget(
      name: "NetworkClientTests",
      dependencies: [
        "NetworkClient",
        "TestExtensions",
      ]
    ),
    .target(
      name: "Environment",
      dependencies: [
        .product(name: "Aegithalos", package: "Aegithalos"),
        "Commons",
        "Crypto",
      ]
    ),
    .testTarget(
      name: "EnvironmentTests",
      dependencies: [
        "Environment",
        "TestExtensions",
      ]
    ),
    .target(
      name: "PassboltApp",
      dependencies: [
        "Accounts",
        "AccountSetup",
        "Commons",
        "UICommons",
        "UIComponents",
        "Features",
        "Resources",
        "Environment",
      ]
    ),
    .testTarget(
      name: "PassboltAppTests",
      dependencies: [
        "PassboltApp",
        "TestExtensions",
      ]
    ),
    .target(
      name: "PassboltExtension",
      dependencies: [
        "Accounts",
        "Commons",
        "UICommons",
        "UIComponents",
        "Features",
        "Resources",
        "Environment",
      ]
    ),
    .testTarget(
      name: "PassboltExtensionTests",
      dependencies: [
        "PassboltExtension",
        "TestExtensions",
      ]
    ),
    .target(
      name: "Resources",
      dependencies: [
        "Accounts",
        "Commons",
        "Features",
        "NetworkClient",
        "Settings",
        "Environment",
      ]
    ),
    .target(
      name: "Settings",
      dependencies: [
        "Commons",
        "Features",
        "Environment",
      ]
    ),
    .target(
      name: "TestExtensions",
      dependencies: [
        "Commons",
        "Features",
        "UIComponents",
      ]
    ),
    .target(
      name: "UICommons",
      dependencies: [
        "Commons",
        .product(name: "AegithalosCocoa", package: "Aegithalos"),
      ],
      resources: [
        .process("Fonts/Inter-Black.ttf"),
        .process("Fonts/Inter-Bold.ttf"),
        .process("Fonts/Inter-ExtraLight.ttf"),
        .process("Fonts/Inter-Light.ttf"),
        .process("Fonts/Inter-Medium.ttf"),
        .process("Fonts/Inter-Regular.ttf"),
        .process("Fonts/Inter-SemiBold.ttf"),
      ]
    ),
    .target(
      name: "UIComponents",
      dependencies: [
        .product(name: "AegithalosCocoa", package: "Aegithalos"),
        "Commons",
        "Features",
        "UICommons",
      ]
    ),
    .testTarget(
      name: "UIComponentsTests",
      dependencies: [
        "UIComponents"
      ]
    ),
    .binaryTarget(
      name: "gopenPGP",
      path: "Vendor/Gopenpgp.xcframework"
    ),
  ]
)
