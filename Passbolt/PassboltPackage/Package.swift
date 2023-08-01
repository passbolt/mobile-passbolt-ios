// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "PassboltPackage",
  defaultLocalization: "en",
  platforms: [.iOS(.v15)],
  products: [
    // MARK: - Legacy
    .library(
      name: "AccountSetup",
      targets: ["AccountSetup"]
    ),
    .library(
      name: "Crypto",
      targets: ["Crypto"]
    ),
    .library(
      name: "NFC",
      targets: ["NFC"]
    ),
    .library(
      name: "SharedUIComponents",
      targets: ["SharedUIComponents"]
    ),
    .library(
      name: "UIComponents",
      targets: ["UIComponents"]
    ),
    // MARK: - Entrypoints
    .library(
      name: "PassboltApp",
      targets: ["PassboltApp"]
    ),
    .library(
      name: "PassboltExtension",
      targets: ["PassboltExtension"]
    ),
    // MARK: - Base
    .library(
      name: "Commons",
      targets: ["Commons"]
    ),
    .library(
      name: "CommonModels",
      targets: ["CommonModels"]
    ),
    .library(
      name: "Localization",
      targets: ["Localization"]
    ),
    .library(
      name: "Features",
      targets: ["Features"]
    ),
    .library(
      name: "FeatureScopes",
      targets: ["FeatureScopes"]
    ),
    .library(
      name: "Display",
      targets: ["Display"]
    ),
    .library(
      name: "UICommons",
      targets: ["UICommons"]
    ),
    .library(
      name: "OSFeatures",
      targets: ["OSFeatures"]
    ),
    // MARK: - Vendor
    .library(
      name: "SQLCipher",
      type: .static,
      targets: ["SQLCipher"]
    ),
    // MARK: - Modules
    .library(
      name: "PassboltAccounts",
      targets: ["PassboltAccounts"]
    ),
    .library(
      name: "PassboltAccountSetup",
      targets: ["PassboltAccountSetup"]
    ),
    .library(
      name: "PassboltSession",
      targets: ["PassboltSession"]
    ),
    .library(
      name: "PassboltSessionData",
      targets: ["PassboltSessionData"]
    ),
    .library(
      name: "PassboltNetworkOperations",
      targets: ["PassboltNetworkOperations"]
    ),
    .library(
      name: "PassboltDatabaseOperations",
      targets: ["PassboltDatabaseOperations"]
    ),
    .library(
      name: "PassboltUsers",
      targets: ["PassboltUsers"]
    ),
    .library(
      name: "PassboltResources",
      targets: ["PassboltResources"]
    ),
    // MARK: - Tests
    .library(
      name: "MockData",
      targets: ["MockData"]
    ),
    .library(
      name: "TestExtensions",
      targets: ["TestExtensions"]
    ),
    .library(
      name: "CoreTest",
      targets: ["CoreTest"]
    ),
  ],
  dependencies: [
    // MARK: - External
    .package(
      url: "https://github.com/miquido/aegithalos.git",
      .upToNextMajor(from: "2.3.1")
    ),
    .package(
      url: "https://github.com/apple/swift-collections.git",
      .upToNextMajor(from: "1.0.4")
    ),
    .package(
      url: "https://github.com/apple/swift-async-algorithms.git",
      .upToNextMinor(from: "0.1.0")
    ),
  ],
  targets: [
    // MARK: - Legacy
    .target(
      name: "Crypto",
      dependencies: [
        "CommonModels",
        "Commons",
        "Gopenpgp",
        "OSFeatures",
        "Features",
        "FeatureScopes",
      ]
    ),
    .testTarget(
      name: "CryptoTests",
      dependencies: [
        "Crypto",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .target(
      name: "NFC",
      dependencies: [
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
      ]
    ),
    .testTarget(
      name: "NFCTests",
      dependencies: [
        "NFC",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .target(
      name: "SharedUIComponents",
      dependencies: [
        "Accounts",
        "CommonModels",
        "Resources",
        "UIComponents",
        "Display",
        "Session",
        "SessionData",
        "FeatureScopes",
      ]
    ),
    .testTarget(
      name: "SharedUIComponentsTests",
      dependencies: [
        "SharedUIComponents",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .target(
      name: "UIComponents",
      dependencies: [
        .product(name: "AegithalosCocoa", package: "Aegithalos"),
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "UICommons",
      ]
    ),
    // MARK: - Entrypoints
    .target(
      name: "PassboltApp",
      dependencies: [
        // Legacy
        "UIComponents",
        "SharedUIComponents",
        "NFC",
        "Crypto",
        // Base
        "Commons",
        "CommonModels",
        "Localization",
        "Features",
        "FeatureScopes",
        "Display",
        "UICommons",
        "OSFeatures",
        // Modules
        "PassboltAccounts",
        "PassboltAccountSetup",
        "PassboltSession",
        "PassboltSessionData",
        "PassboltNetworkOperations",
        "PassboltDatabaseOperations",
        "PassboltUsers",
        "PassboltResources",
      ]
    ),
    .target(
      name: "PassboltExtension",
      dependencies: [
        // Legacy
        "UIComponents",
        "SharedUIComponents",
        "Crypto",
        // Base
        "Commons",
        "CommonModels",
        "Localization",
        "Features",
        "FeatureScopes",
        "Display",
        "UICommons",
        "OSFeatures",
        // Modules
        "PassboltAccounts",
        "PassboltSession",
        "PassboltSessionData",
        "PassboltNetworkOperations",
        "PassboltDatabaseOperations",
        "PassboltUsers",
        "PassboltResources",
      ]
    ),
    // MARK: - Base
    .target(
      name: "Commons",
      dependencies: [
        // Base
        "Localization",
        // External
        .product(
          name: "OrderedCollections",
          package: "swift-collections"
        ),
        .product(
          name: "AsyncAlgorithms",
          package: "swift-async-algorithms"
        ),
      ]
    ),
    .target(
      name: "CommonModels",
      dependencies: [
        // Base
        "Commons"
      ]
    ),
    .target(
      name: "Localization",
      dependencies: []
    ),
    .target(
      name: "Features",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
      ]
    ),
    .target(
      name: "FeatureScopes",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "Resources",
        "DatabaseOperations",
      ]
    ),
    .target(
      name: "Display",
      dependencies: [
        // Legacy
        "UIComponents",
        // Base
        "Commons",
        "Features",
        "FeatureScopes",
      ]
    ),
    .target(
      name: "UICommons",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Crypto",
        // Modules
        "Accounts",
        "Users",
        "Resources",
        // External
        .product(
          name: "AegithalosCocoa",
          package: "Aegithalos"
        ),
      ],
      resources: [
        .process("Fonts/Inconsolata Bold.ttf"),
        .process("Fonts/Inconsolata SemiBold.ttf"),
        .process("Fonts/Inconsolata Regular.ttf"),
        .process("Fonts/Inconsolata Light.ttf"),
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
      name: "Database",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        // Vendor
        "SQLCipher",
      ]
    ),
    // MARK: - Vendor
    .binaryTarget(
      name: "Gopenpgp",
      path: "./Vendor/Gopenpgp.xcframework"
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
      name: "OSFeatures",
      dependencies: [
        // Base
        "Commons",
        "Features",
        // External
        .product(
          name: "Aegithalos",
          package: "Aegithalos"
        ),
      ]
    ),
    // MARK: - Modules
    .target(
      name: "Accounts",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
      ]
    ),
    .target(
      name: "PassboltAccounts",
      dependencies: [
        // Legacy
        "Crypto",
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        // Modules
        "Accounts",
        "Session",
        "NetworkOperations",
      ]
    ),
    .target(
      name: "AccountSetup",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
      ]
    ),
    .target(
      name: "PassboltAccountSetup",
      dependencies: [
        // Legacy
        "Crypto",
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "OSFeatures",
        // Modules
        "Accounts",
        "AccountSetup",
        "NetworkOperations",
        "DatabaseOperations",
        "Session",
      ]
    ),
    .target(
      name: "Session",
      dependencies: [
        // Legacy
        "Crypto",
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "Database",
        // Modules
        "Accounts",
        // External
        .product(
          name: "Aegithalos",
          package: "Aegithalos"
        ),
      ]
    ),
    .target(
      name: "PassboltSession",
      dependencies: [
        // Legacy
        "Crypto",
        "NFC",
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "Database",
        "OSFeatures",
        // Modules
        "Accounts",
        "Session",
        "DatabaseOperations",
        "NetworkOperations",
      ]
    ),
    .target(
      name: "NetworkOperations",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        // Modules
        "Accounts",
        "Session",
        // External
        .product(
          name: "Aegithalos",
          package: "Aegithalos"
        ),
      ]
    ),
    .target(
      name: "PassboltNetworkOperations",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "OSFeatures",
        // Modules
        "Accounts",
        "Session",
        "NetworkOperations",
      ]
    ),
    .target(
      name: "DatabaseOperations",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "Database",
        // Modules
        "Accounts",
      ]
    ),
    .target(
      name: "PassboltDatabaseOperations",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "Database",
        "OSFeatures",
        // Modules
        "Accounts",
        "Session",
        "DatabaseOperations",
      ]
    ),
    .target(
      name: "SessionData",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
      ]
    ),
    .target(
      name: "PassboltSessionData",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "Database",
        // Modules
        "Accounts",
        "Session",
        "DatabaseOperations",
        "NetworkOperations",
        "Users",
        "Resources",
        "SessionData",
      ]
    ),
    .target(
      name: "Users",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
      ]
    ),
    .target(
      name: "PassboltUsers",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        // Modules
        "Accounts",
        "Session",
        "SessionData",
        "DatabaseOperations",
        "NetworkOperations",
        "Users",
      ]
    ),
    .target(
      name: "Resources",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
      ]
    ),
    .target(
      name: "PassboltResources",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        // Modules
        "Accounts",
        "Session",
        "SessionData",
        "DatabaseOperations",
        "NetworkOperations",
        "Users",
        "Resources",
      ]
    ),
    // MARK: - Tests
    .target(
      name: "MockData",
      dependencies: [
        // Base
        "Commons",
        "CommonModels",
        // Modules
        "PassboltAccounts",
        "PassboltAccountSetup",
        "PassboltApp",
        "PassboltDatabaseOperations",
        "PassboltExtension",
        "PassboltNetworkOperations",
        "PassboltResources",
        "PassboltSession",
        "PassboltSessionData",
        "PassboltUsers",
      ]
    ),
    .target(
      name: "CoreTest",
      dependencies: []
    ),
    .target(
      name: "TestExtensions",
      dependencies: [
        // Legacy
        "UIComponents",
        // Base
        "Commons",
        "CommonModels",
        "Features",
        "FeatureScopes",
        "Database",
        "OSFeatures",
        // Modules
        "Accounts",
        "Session",
        "SessionData",
        "Resources",
        "Users",
        "DatabaseOperations",
        "NetworkOperations",
        // Test
        "MockData",
        "CoreTest",
      ]
    ),
    .testTarget(
      name: "PassboltAppTests",
      dependencies: [
        "PassboltApp",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "PassboltExtensionTests",
      dependencies: [
        "PassboltExtension",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "CommonsTests",
      dependencies: [
        "Commons",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "CommonModelsTests",
      dependencies: [
        "CommonModels",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "FeaturesTests",
      dependencies: [
        "Features",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "PassboltAccountsTests",
      dependencies: [
        "PassboltAccounts",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "PassboltAccountSetupTests",
      dependencies: [
        "PassboltAccountSetup",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "PassboltSessionTests",
      dependencies: [
        "PassboltSession",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "PassboltUsersTests",
      dependencies: [
        "PassboltUsers",
        "CoreTest",
        "TestExtensions",
      ]
    ),
    .testTarget(
      name: "PassboltResourcesTests",
      dependencies: [
        "PassboltResources",
        "CoreTest",
        "TestExtensions",
      ]
    ),
  ]
)
