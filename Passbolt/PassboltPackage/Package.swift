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
      name: "CommonDataModels",
      targets: ["CommonDataModels"]
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
      name: "NFC",
      targets: ["NFC"]
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
      name: "SharedUIComponents",
      targets: [
        "SharedUIComponents"
      ]
    ),
    .library(
      name: "SQLCipher",
      type: .static,
      targets: [
        "SQLCipher"
      ]
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
      name: "Users",
      targets: ["Users"]
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
      .upToNextMajor(from: "2.3.0")
    )
  ],
  targets: [
    .target(
      name: "Accounts",
      dependencies: [
        "CommonDataModels",
        "Commons",
        "Crypto",
        "Features",
        "NetworkClient",
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
      name: "CommonDataModels",
      dependencies: [
        "Commons"
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
        "CommonDataModels",
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
      name: "NFC",
      dependencies: [
        "Commons"
      ]
    ),
    .testTarget(
      name: "NFCTests",
      dependencies: [
        "NFC",
        "TestExtensions",
      ]
    ),
    .target(
      name: "Environment",
      dependencies: [
        .product(name: "Aegithalos", package: "Aegithalos"),
        "Commons",
        "Crypto",
        "SQLCipher",
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
      name: "Users",
      dependencies: [
        "Accounts",
        "CommonDataModels",
        "Commons",
        "Crypto",
        "Features",
        "NetworkClient",
      ]
    ),
    .testTarget(
      name: "UsersTests",
      dependencies: [
        "Users",
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
        "SharedUIComponents",
        "NFC",
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
        "SharedUIComponents",
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
        "CommonDataModels",
        "Commons",
        "Crypto",
        "Features",
        "NetworkClient",
        "Environment",
        "Users",
      ]
    ),
    .testTarget(
      name: "ResourcesTests",
      dependencies: [
        "Resources",
        "TestExtensions",
      ]
    ),
    .target(
      name: "SharedUIComponents",
      dependencies: [
        "Accounts",
        "UIComponents",
      ],
      resources: [
        .process("Localizable.strings")
      ]
    ),
    .testTarget(
      name: "SharedUIComponentsTests",
      dependencies: [
        "SharedUIComponents",
        "TestExtensions",
      ]
    ),
    .target(
      // SQLCipher is added as preconfigured source file
      // see: https://www.zetetic.net/sqlcipher/ios-tutorial/#option-1-source-integration
      // however due to some issuse with SPM (or generated source)
      // it is currently required to add define for SQLITE_HAS_CODEC in sqlite3.h
      // it won't be compiled properly otherwise.
      //
      // Put it after:
      // "Provide the ability to override linkage features of the interface."
      // comment, around line ~70.
      //
      // #ifndef SQLITE_HAS_CODEC
      // # define SQLITE_HAS_CODEC
      // #endif
      //
      // It might be updated in future see: https://github.com/sqlcipher/sqlcipher/issues/371
      name: "SQLCipher",
      cSettings: [
        .define("SQLITE_HAS_CODEC"),
        .define("SQLITE_TEMP_STORE", to: "3"),
        .define("SQLCIPHER_CRYPTO_CC"),
        .define("NDEBUG"),  // Settings based on recommended values: https://www.sqlite.org/draft/security.html
        .define("SQLITE_MAX_LIMIT_LENGTH", to: "1000000"),
        .define("SQLITE_MAX_SQL_LENGTH", to: "100000"),
        .define("SQLITE_MAX_LIMIT_COLUMN", to: "100"),
        .define("SQLITE_MAX_LIMIT_EXPR_DEPTH", to: "10"),
        .define("SQLITE_MAX_LIMIT_COMPOUND_SELECT", to: "3"),
        .define("SQLITE_MAX_LIMIT_VDBE_OP", to: "25000"),
        .define("SQLITE_MAX_LIMIT_FUNCTION_ARG", to: "8"),
        .define("SQLITE_MAX_LIMIT_ATTACH", to: "0"),
        .define("SQLITE_MAX_LIMIT_LIKE_PATTERN_LENGTH", to: "50"),
        .define("SQLITE_MAX_LIMIT_VARIABLE_NUMBER", to: "10"),
        .define("SQLITE_MAX_LIMIT_TRIGGER_DEPTH", to: "10"),
      ],
      swiftSettings: [
        .define("SQLITE_HAS_CODEC")
      ],
      linkerSettings: [
        .linkedFramework("Foundation"),
        .linkedFramework("Security"),
      ]
    ),
    .target(
      name: "TestExtensions",
      dependencies: [
        "Commons",
        "Features",
        "UIComponents",
        "NetworkClient",
      ]
    ),
    .target(
      name: "UICommons",
      dependencies: [
        "Commons",
        .product(name: "AegithalosCocoa", package: "Aegithalos"),
      ],
      resources: [
        .process("Fonts/Inconsolata Bold.ttf"),
        .process("Fonts/Inconsolata SemiBold.ttf"),
        .process("Fonts/Inter Black.otf"),
        .process("Fonts/Inter Bold.otf"),
        .process("Fonts/Inter Extra Light.otf"),
        .process("Fonts/Inter Light.otf"),
        .process("Fonts/Inter Medium.otf"),
        .process("Fonts/Inter Regular.otf"),
        .process("Fonts/Inter Semi Bold.otf"),
        .process("Fonts/Inter Thin.otf"),
        .process("Fonts/Inter Italic.otf"),
        .process("Fonts/Inter Light Italic.otf"),
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
